# A minimal in-process IMAP server for exercising Net::IMAP against real sockets, without
# depending on a live mail server. Speaks just enough of the protocol (CAPABILITY, LOGIN,
# LIST/XLIST, LOGOUT) to drive the scenarios our services care about.
class FakeImapServer
  attr_reader :port

  def initialize(capabilities: "IMAP4rev1", login_ok: true, folders: [], use_xlist: false)
    @server = TCPServer.new("127.0.0.1", 0)
    @port = @server.addr[1]
    @capabilities = capabilities
    @login_ok = login_ok
    @folders = folders
    @list_command = use_xlist ? "XLIST" : "LIST"
    @thread = nil
  end

  def start
    @thread = Thread.new { serve_one_connection }
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

    while (line = socket.gets)
      tag, command, = line.strip.split(" ", 3)
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
      when "LOGOUT"
        socket.write("* BYE logging out\r\n")
        socket.write("#{tag} OK LOGOUT completed\r\n")
        break
      else
        socket.write("#{tag} BAD unknown command\r\n")
      end
    end
  rescue IOError, Errno::EBADF, Errno::EPIPE
    nil
  ensure
    socket&.close
  end
end
