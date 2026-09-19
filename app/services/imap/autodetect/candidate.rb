module Imap
  class Autodetect
    # One "here is where the mailbox might be" to try: an endpoint plus the usernames worth
    # trying on it. Autoconfig states the username form, so it yields a single one; anything
    # we inferred has to try the full address and the local part, which providers split
    # roughly evenly between.
    Candidate = Struct.new(:host, :port, :tls, :usernames, keyword_init: true) do
      def ssl?
        tls == :ssl
      end

      def starttls?
        tls == :starttls
      end

      def key
        [ host, port, tls ]
      end
    end
  end
end
