# A minimal in-process IMAP server for exercising Net::IMAP against real sockets, without
# depending on a live mail server. Speaks just enough of the protocol (CAPABILITY, LOGIN,
# LIST/XLIST, EXAMINE, UID SEARCH, UID FETCH, LOGOUT) to drive the scenarios our services
# care about. It accepts any number of connections, one after the other.
#
# `mailboxes` maps a folder name to { uidvalidity:, messages: [...] }; each message is a hash
# with :uid and optionally :flags, :internaldate, :size, :envelope (see #envelope),
# :bodystructure (a raw IMAP BODYSTRUCTURE string) and :body (the raw RFC822 source, returned
# as a BODY[] literal when a FETCH asks for BODY[] or BODY.PEEK[]). The hash is read on every
# command, so a test can mutate it between syncs. `drop_on_fetch_of` closes the connection when
# a UID FETCH asks for that UID, simulating a crash mid-folder. `uidnext: false` on a mailbox
# leaves out the optional UIDNEXT response.
#
# `gmail: true` makes it behave like Gmail: it advertises X-GM-EXT-1 and XLIST, lists INBOX plus
# the `[Gmail]/...` system folders (All Mail, Sent Mail, Trash, Spam, Important, Starred) next to
# whatever `folders:` adds, answers FETCH with X-GM-MSGID, and moves the Gmail way: a MOVE out of
# a label folder only removes that label (the message stays in All Mail), and a MOVE into
# `[Gmail]/Trash` takes the message out of every other folder. Use #add_gmail_message to file one
# message under several labels at once: each copy shares its Message-ID and X-GM-MSGID.
class FakeImapServer
  GMAIL_CAPABILITIES = "IMAP4rev1 UIDPLUS MOVE X-GM-EXT-1 XLIST"
  GMAIL_ALL_MAIL = "[Gmail]/All Mail"
  GMAIL_TRASH = "[Gmail]/Trash"
  GMAIL_SYSTEM_FOLDERS = {
    "INBOX" => nil,
    "[Gmail]/All Mail" => "AllMail",
    "[Gmail]/Sent Mail" => "Sent",
    "[Gmail]/Trash" => "Trash",
    "[Gmail]/Spam" => "Spam",
    "[Gmail]/Important" => "Important",
    "[Gmail]/Starred" => "Starred"
  }.freeze

  attr_reader :port, :fetched_uid_sets, :commands

  def initialize(capabilities: "IMAP4rev1", login_ok: true, folders: [], use_xlist: false, mailboxes: {}, drop_on_fetch_of: nil, namespace_prefix: nil, refuse_store: false, gmail: false)
    @server = TCPServer.new("127.0.0.1", 0)
    @port = @server.addr[1]
    @gmail = gmail
    @capabilities = gmail && capabilities == "IMAP4rev1" ? GMAIL_CAPABILITIES : capabilities
    @login_ok = login_ok
    @folders = folders
    @list_command = use_xlist || gmail ? "XLIST" : "LIST"
    @mailboxes = mailboxes
    setup_gmail_folders if gmail
    @drop_on_fetch_of = drop_on_fetch_of
    @fetched_uid_sets = []
    @commands = []
    @namespace_prefix = namespace_prefix
    @refuse_store = refuse_store
    @refuse_store = refuse_store
    @thread = nil
  end

  attr_accessor :drop_on_fetch_of

  # Gmail only: files one message under each of `labels` (folder names, INBOX included) and in
  # All Mail, all with the same Message-ID and X-GM-MSGID. Returns the shared X-GM-MSGID.
  def add_gmail_message(labels:, message_id:, **message)
    gm_msgid = message.delete(:gm_msgid) || gmail_msgid_for(message_id)
    envelope = (message.delete(:envelope) || {}).merge(message_id:)
    (Array(labels) | [ GMAIL_ALL_MAIL ]).each do |name|
      mailbox = @mailboxes[name] or raise ArgumentError, "unknown Gmail folder #{name}"
      uid = (mailbox_uids(mailbox).max || 0) + 1
      mailbox[:messages] << message.merge(uid:, envelope:, gm_msgid:)
    end
    gm_msgid
  end

  def start
    @thread = Thread.new { loop { serve_one_connection } }
    self
  end

  def stop
    @thread&.kill
    @thread&.join(1)
    @accepted&.each { |socket| socket.close unless socket.closed? }
    @server.close unless @server.closed?
  end

  # Returns a fake server that answers in plaintext even though the client connects
  # expecting TLS, to simulate a TLS handshake failing against a plaintext-only endpoint:
  # the client's TLS engine chokes trying to parse the plaintext bytes as a TLS record.
  def self.tls_trap
    server = new
    accepted = (server.instance_variable_set(:@accepted, []))
    server.instance_variable_set(:@thread, Thread.new do
      loop do
        socket = server.instance_variable_get(:@server).accept
        accepted << socket
        socket.write("* OK IMAP4rev1 Service Ready\r\n")
      end
    rescue IOError, Errno::EBADF, Errno::EPIPE
      nil
    end)
    server
  end

  private

  def setup_gmail_folders
    GMAIL_SYSTEM_FOLDERS.each_with_index do |(name, xlist), index|
      @folders << { name:, attrs: [ xlist, "HasNoChildren" ].compact } unless @folders.any? { |f| f[:name] == name }
      @mailboxes[name] ||= { uidvalidity: 700 + index, messages: [] }
    end
    @mailboxes.each_key do |name|
      @folders << { name:, attrs: [ "HasNoChildren" ] } unless @folders.any? { |f| f[:name] == name }
    end
    @folders.sort_by!.with_index { |f, i| [ GMAIL_SYSTEM_FOLDERS.keys.index(f[:name]) || GMAIL_SYSTEM_FOLDERS.size, i ] }
  end

  # One stable, Gmail-looking 64-bit id per Message-ID.
  def gmail_msgid_for(message_id)
    1_700_000_000_000_000_000 + message_id.to_s.bytes.each_with_index.sum { |byte, i| byte * (i + 1) * 7919 }
  end

  def gmail_msgid(message)
    message[:gm_msgid] || gmail_msgid_for(message.dig(:envelope, :message_id) || message[:uid])
  end

  def gmail_label_folder?(name)
    !GMAIL_SYSTEM_FOLDERS.key?(name) || name == "INBOX"
  end

  # Gmail's MOVE/COPY: labels are folders, All Mail holds the one real copy. Returns the new UIDs.
  def gmail_transfer(command, source_name, destination_name, matched)
    source = @mailboxes[source_name]
    destination = @mailboxes[destination_name]
    matched.map do |uid|
      message = source[:messages].find { |m| m[:uid] == uid }
      id = gmail_msgid(message)
      if destination_name == GMAIL_TRASH && command == "MOVE"
        @mailboxes.each do |name, mailbox|
          mailbox[:messages].reject! { |m| name != GMAIL_TRASH && gmail_msgid(m) == id }
        end
      elsif command == "MOVE" && gmail_label_folder?(source_name)
        source[:messages].delete(message)
      end
      existing = destination[:messages].find { |m| gmail_msgid(m) == id }
      next existing[:uid] if existing

      new_uid = (mailbox_uids(destination).max || 0) + 1
      destination[:messages] << message.merge(uid: new_uid, gm_msgid: id)
      new_uid
    end
  end

  def serve_one_connection
    socket = @server.accept
    socket.write("* OK IMAP4rev1 Service Ready\r\n")
    selected = nil

    while (line = socket.gets)
      tag, command, args = line.strip.split(" ", 3)
      @commands << [ command, args ].compact.join(" ")
      case command&.upcase
      when "CAPABILITY"
        socket.write("* CAPABILITY #{@capabilities}\r\n")
        socket.write("#{tag} OK CAPABILITY completed\r\n")
      when "LOGIN"
        if @login_ok
          socket.write("#{tag} OK LOGIN completed\r\n")
        else
          socket.write("#{tag} NO LOGIN failed\r\n")
        end
      when "LIST", "XLIST"
        @folders.each do |folder|
          attrs = Array(folder[:attrs]).map { |a| "\\#{a}" }.join(" ")
          socket.write(%(* #{@list_command} (#{attrs}) "/" "#{folder[:name]}"\r\n))
        end
        socket.write("#{tag} OK #{command.upcase} completed\r\n")
      when "NAMESPACE"
        socket.write(%(* NAMESPACE ((#{@namespace_prefix ? %("#{@namespace_prefix}" "/") : %("" "/")})) NIL NIL\r\n))
        socket.write("#{tag} OK NAMESPACE completed\r\n")
      when "STATUS"
        name, _items = args.split(" ", 2)
        mailbox = @mailboxes[unquote(name)]
        if mailbox
          unseen = mailbox[:messages].count { |m| !Array(m[:flags]).include?("\\Seen") }
          socket.write(%(* STATUS #{name} (MESSAGES #{mailbox[:messages].size} UNSEEN #{unseen})\r\n))
          socket.write("#{tag} OK STATUS completed\r\n")
        else
          socket.write("#{tag} NO no such mailbox\r\n")
        end
      when "CREATE"
        name = unquote(args)
        if @namespace_prefix && !name.start_with?(@namespace_prefix)
          socket.write("#{tag} NO [CANNOT] folders must live under #{@namespace_prefix}\r\n")
        elsif @mailboxes.key?(name)
          socket.write("#{tag} NO [ALREADYEXISTS] Mailbox exists\r\n")
        else
          @mailboxes[name] = { uidvalidity: 500 + @mailboxes.size, messages: [] }
          @folders << { name: name }
          socket.write("#{tag} OK CREATE completed\r\n")
        end
      when "APPEND"
        name = unquote(args.split(" ", 2).first)
        size = args[/\{(\d+)\+?\}\z/, 1].to_i
        socket.write("+ Ready for literal data\r\n")
        raw = socket.read(size)
        socket.gets
        mailbox = @mailboxes[name]
        if mailbox
          uid = (mailbox_uids(mailbox).max || 0) + 1
          flags = args[/\(([^)]*)\)/, 1].to_s.split
          mailbox[:messages] << { uid:, flags:, body: raw }
          code = @capabilities.include?("UIDPLUS") ? "[APPENDUID #{mailbox[:uidvalidity]} #{uid}] " : ""
          socket.write("#{tag} OK #{code}APPEND completed\r\n")
        else
          socket.write("#{tag} NO [TRYCREATE] no such mailbox\r\n")
        end
      when "SELECT", "EXAMINE"
        selected = unquote(args)
        mailbox = @mailboxes[selected]
        if mailbox
          uids = mailbox_uids(mailbox)
          socket.write("* #{uids.size} EXISTS\r\n")
          socket.write("* OK [UIDVALIDITY #{mailbox[:uidvalidity]}] UIDs valid\r\n") if mailbox[:uidvalidity]
          socket.write("* OK [UIDNEXT #{(uids.max || 0) + 1}] Predicted next UID\r\n") unless mailbox[:uidnext] == false
          socket.write("#{tag} OK [#{command.casecmp?("SELECT") ? "READ-WRITE" : "READ-ONLY"}] #{command.upcase} completed\r\n")
        else
          selected = nil
          socket.write("#{tag} NO Mailbox does not exist\r\n")
        end
      when "UID"
        subcommand, rest = args.split(" ", 2)
        mailbox = @mailboxes[selected]
        case subcommand.upcase
        when "SEARCH"
          set = rest.sub(/\AUID /i, "").split(" ").first
          matched = matching_uids(mailbox, set)
          socket.write("* SEARCH#{matched.map { |uid| " #{uid}" }.join}\r\n")
          socket.write("#{tag} OK SEARCH completed\r\n")
        when "FETCH"
          set, requested = rest.split(" ", 2)
          matched = matching_uids(mailbox, set)
          @fetched_uid_sets << matched
          break if @drop_on_fetch_of && matched.include?(@drop_on_fetch_of)

          uids = mailbox_uids(mailbox)
          mailbox[:messages].select { |m| matched.include?(m[:uid]) }.each do |message|
            items = fetch_items(message)
            items += " #{body_item(message)}" if requested.to_s.match?(/BODY(\.PEEK)?\[\]/) && message[:body]
            socket.write("* #{uids.index(message[:uid]) + 1} FETCH (#{items})\r\n")
          end
          socket.write("#{tag} OK FETCH completed\r\n")
        when "COPY", "MOVE"
          set, target = rest.split(" ", 2)
          destination = @mailboxes[unquote(target)]
          matched = matching_uids(mailbox, set)
          if destination.nil?
            socket.write("#{tag} NO [TRYCREATE] no such mailbox\r\n")
          else
            assigned = if @gmail
              gmail_transfer(subcommand.upcase, selected, unquote(target), matched)
            else
              matched.map do |uid|
                message = mailbox[:messages].find { |m| m[:uid] == uid }
                mailbox[:messages].delete(message) if subcommand.upcase == "MOVE"
                new_uid = (mailbox_uids(destination).max || 0) + 1
                destination[:messages] << message.merge(uid: new_uid)
                new_uid
              end
            end
            code = "[COPYUID #{destination[:uidvalidity]} #{matched.join(",")} #{assigned.join(",")}]"
            if subcommand.upcase == "MOVE"
              socket.write("* OK #{code}\r\n")
              socket.write("#{tag} OK MOVE completed\r\n")
            else
              socket.write("#{tag} OK #{code} COPY completed\r\n")
            end
          end
        when "STORE"
          set, mode, list = rest.split(" ", 3)
          names = list.to_s.delete("()").split
          if @refuse_store
            socket.write("#{tag} NO STORE refused\r\n")
          else
            matching_uids(mailbox, set).each do |uid|
              message = mailbox[:messages].find { |m| m[:uid] == uid }
              current = Array(message[:flags])
              message[:flags] = mode.upcase.start_with?("-") ? current - names : (current | names)
            end
            socket.write("#{tag} OK STORE completed\r\n")
          end
        when "EXPUNGE"
          matched = matching_uids(mailbox, rest)
          mailbox[:messages].reject! { |m| matched.include?(m[:uid]) && Array(m[:flags]).include?("\\Deleted") }
          socket.write("#{tag} OK EXPUNGE completed\r\n")
        else
          socket.write("#{tag} BAD unknown command\r\n")
        end
      when "LOGOUT"
        socket.write("* BYE logging out\r\n")
        socket.write("#{tag} OK LOGOUT completed\r\n")
        break
      else
        socket.write("#{tag} BAD unknown command\r\n")
      end
    end
  rescue IOError, Errno::EBADF, Errno::EPIPE, Errno::ECONNRESET
    nil
  ensure
    socket&.close
  end

  def unquote(value)
    value = value.to_s.strip
    value.start_with?('"') ? value[1...-1].gsub(/\\(.)/, '\\1') : value
  end

  def mailbox_uids(mailbox)
    mailbox[:messages].map { |m| m[:uid] }.sort
  end

  # Resolves an IMAP sequence set ("1:3,7,9:*") against the mailbox's UIDs. As on a real
  # server, "*" is the highest UID, so "n:*" matches that message even when it is below n.
  def matching_uids(mailbox, set)
    uids = mailbox_uids(mailbox)
    return [] if uids.empty?

    set.split(",").flat_map { |range|
      from, to = range.split(":").map { |bound| bound == "*" ? uids.max : bound.to_i }
      to ||= from
      low, high = [ from, to ].minmax
      uids.select { |uid| uid.between?(low, high) }
    }.uniq.sort
  end

  def fetch_items(message)
    [
      "UID #{message[:uid]}",
      *(@gmail ? [ "X-GM-MSGID #{gmail_msgid(message)}" ] : []),
      "FLAGS (#{Array(message[:flags]).join(" ")})",
      %(INTERNALDATE "#{message[:internaldate] || "17-Sep-2026 10:00:00 +0200"}"),
      "RFC822.SIZE #{message[:size] || 1024}",
      "ENVELOPE #{envelope(message[:envelope] || {})}",
      "BODYSTRUCTURE #{message[:bodystructure] || '("TEXT" "PLAIN" ("CHARSET" "UTF-8") NIL NIL "7BIT" 12 1 NIL NIL NIL NIL)'}"
    ].join(" ")
  end

  # Builds an ENVELOPE from { date:, subject:, from:, to:, cc:, in_reply_to:, message_id: },
  # where the address lists are arrays of [name, "mailbox@host"].
  def envelope(fields)
    addresses = ->(list) {
      next "NIL" if list.blank?

      "(" + list.map { |name, address|
        mailbox, host = address.split("@", 2)
        "(#{quote(name)} NIL #{quote(mailbox)} #{quote(host)})"
      }.join + ")"
    }
    from = addresses.call(fields[:from])

    [
      quote(fields[:date]), quote(fields[:subject]), from, from, from,
      addresses.call(fields[:to]), addresses.call(fields[:cc]), "NIL",
      quote(fields[:in_reply_to]), quote(fields[:message_id])
    ].join(" ").then { |items| "(#{items})" }
  end

  # A real server echoes "BODY[]" regardless of whether BODY[] or BODY.PEEK[] was requested.
  def body_item(message)
    bytes = message[:body].to_s.b
    "BODY[] {#{bytes.bytesize}}\r\n#{bytes}"
  end

  # 8-bit values are sent as literals, as real servers do.
  def quote(value)
    return "NIL" if value.nil?

    bytes = value.b
    return "{#{bytes.bytesize}}\r\n#{bytes}" unless bytes.ascii_only?

    %("#{bytes.gsub(/(["\\])/, '\\\\\\1')}")
  end
end
