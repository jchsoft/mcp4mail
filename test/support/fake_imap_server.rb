# A minimal in-process IMAP server for exercising Net::IMAP against real sockets, without
# depending on a live mail server. Speaks just enough of the protocol (CAPABILITY, LOGIN,
# LIST/XLIST, EXAMINE, UID SEARCH, UID FETCH, LOGOUT) to drive the scenarios our services
# care about. It accepts any number of connections, one after the other.
#
# `mailboxes` maps a folder name to { uidvalidity:, messages: [...] }; each message is a hash
# with :uid and optionally :flags, :internaldate, :size, :envelope (see #envelope) and
# :bodystructure (a raw IMAP BODYSTRUCTURE string). The hash is read on every command, so a
# test can mutate it between syncs. `drop_on_fetch_of` closes the connection when a
# UID FETCH asks for that UID, simulating a crash mid-folder. `uidnext: false` on a mailbox
# leaves out the optional UIDNEXT response.
class FakeImapServer
  attr_reader :port, :fetched_uid_sets

  def initialize(capabilities: "IMAP4rev1", login_ok: true, folders: [], use_xlist: false, mailboxes: {}, drop_on_fetch_of: nil)
    @server = TCPServer.new("127.0.0.1", 0)
    @port = @server.addr[1]
    @capabilities = capabilities
    @login_ok = login_ok
    @folders = folders
    @list_command = use_xlist ? "XLIST" : "LIST"
    @mailboxes = mailboxes
    @drop_on_fetch_of = drop_on_fetch_of
    @fetched_uid_sets = []
    @thread = nil
  end

  attr_accessor :drop_on_fetch_of

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

  def serve_one_connection
    socket = @server.accept
    socket.write("* OK IMAP4rev1 Service Ready\r\n")
    selected = nil

    while (line = socket.gets)
      tag, command, args = line.strip.split(" ", 3)
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
      when "SELECT", "EXAMINE"
        selected = unquote(args)
        mailbox = @mailboxes[selected]
        if mailbox
          uids = mailbox_uids(mailbox)
          socket.write("* #{uids.size} EXISTS\r\n")
          socket.write("* OK [UIDVALIDITY #{mailbox[:uidvalidity]}] UIDs valid\r\n") if mailbox[:uidvalidity]
          socket.write("* OK [UIDNEXT #{(uids.max || 0) + 1}] Predicted next UID\r\n") unless mailbox[:uidnext] == false
          socket.write("#{tag} OK [READ-ONLY] #{command.upcase} completed\r\n")
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
          set = rest.split(" ").first
          matched = matching_uids(mailbox, set)
          @fetched_uid_sets << matched
          break if @drop_on_fetch_of && matched.include?(@drop_on_fetch_of)

          uids = mailbox_uids(mailbox)
          mailbox[:messages].select { |m| matched.include?(m[:uid]) }.each do |message|
            socket.write("* #{uids.index(message[:uid]) + 1} FETCH (#{fetch_items(message)})\r\n")
          end
          socket.write("#{tag} OK FETCH completed\r\n")
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

  # 8-bit values are sent as literals, as real servers do.
  def quote(value)
    return "NIL" if value.nil?

    bytes = value.b
    return "{#{bytes.bytesize}}\r\n#{bytes}" unless bytes.ascii_only?

    %("#{bytes.gsub(/(["\\])/, '\\\\\\1')}")
  end
end
