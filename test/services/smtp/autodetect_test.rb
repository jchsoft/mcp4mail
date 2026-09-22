require "test_helper"

class Smtp::AutodetectTest < ActiveSupport::TestCase
  # The lookups and the EHLO + AUTH check stand in for DNS and real servers: the test decides
  # what each source offers and which host:port accepts the login.
  class Scripted < Smtp::Autodetect
    def initialize(mail_account, autoconfig: [], srv: [], accepts: [])
      super(mail_account)
      @autoconfig = autoconfig
      @srv = srv
      @accepts = accepts
    end

    private
      def autoconfig_candidates = @autoconfig
      def srv_candidates = @srv
      def verify(candidate) = @accepts.include?([ candidate.host, candidate.port ])
  end

  setup do
    @account = mail_accounts(:work)
  end

  test "an autoconfig answer that accepts the login wins over guesses" do
    offered = Smtp::Autodetect::Settings.new(host: "out.example.com", port: 587, tls: :starttls)

    found = Scripted.new(@account, autoconfig: [ offered ], accepts: [ [ "out.example.com", 587 ], [ "smtp.example.com", 465 ] ]).call

    assert_equal [ "out.example.com", 587, :starttls ], [ found.host, found.port, found.tls ]
  end

  test "guesses try smtp., mail. and the IMAP host, implicit TLS on 465 before STARTTLS on 587" do
    guesses = Scripted.new(@account).send(:guess_candidates).map { |settings| [ settings.host, settings.port, settings.tls ] }

    assert_equal [
      [ "smtp.example.com", 465, :ssl ], [ "smtp.example.com", 587, :starttls ],
      [ "mail.example.com", 465, :ssl ], [ "mail.example.com", 587, :starttls ],
      [ "imap.example.com", 465, :ssl ], [ "imap.example.com", 587, :starttls ]
    ], guesses
  end

  test "the first guess in preference order wins, not the fastest" do
    found = Scripted.new(@account, accepts: [ [ "mail.example.com", 587 ], [ "smtp.example.com", 587 ] ]).call

    assert_equal [ "smtp.example.com", 587, :starttls ], [ found.host, found.port, found.tls ]
  end

  test "nothing that accepts the login finds nothing" do
    assert_nil Scripted.new(@account).call
  end
end
