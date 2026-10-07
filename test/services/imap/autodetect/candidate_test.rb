require "test_helper"

class Imap::Autodetect::CandidateTest < ActiveSupport::TestCase
  def candidate(tls, port: 993)
    Imap::Autodetect::Candidate.new(host: "imap.example.com", port: port, tls: tls, usernames: [ "bob@example.com" ])
  end

  test "ssl? is true only for implicit TLS" do
    assert candidate(:ssl).ssl?
    assert_not candidate(:starttls).ssl?
  end

  test "starttls? is true only for an upgraded plaintext connection" do
    assert candidate(:starttls, port: 143).starttls?
    assert_not candidate(:ssl).starttls?
  end

  test "key identifies the endpoint, not the usernames" do
    assert_equal [ "imap.example.com", 993, :ssl ], candidate(:ssl).key
    assert_equal candidate(:ssl).key, candidate(:ssl).tap { |c| c.usernames = [ "bob" ] }.key
    assert_not_equal candidate(:ssl).key, candidate(:starttls).key
  end
end
