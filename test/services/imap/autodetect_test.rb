require "test_helper"
require_relative "../../support/fake_autodetect_network"

class Imap::AutodetectTest < ActiveSupport::TestCase
  include FakeAutodetectNetwork

  EMAIL = "bob@example.com".freeze
  ISPDB = "/v1.1/example.com".freeze
  PROVIDER_DOC = "/mail/config-v1.1.xml?emailaddress=bob%40example.com".freeze

  def client_config(host, port, socket_type: "SSL", username: "%EMAILADDRESS%")
    <<~XML
      <?xml version="1.0"?>
      <clientConfig version="1.1">
        <emailProvider id="example.com">
          <incomingServer type="pop3">
            <hostname>pop.example.com</hostname><port>995</port><socketType>SSL</socketType>
            <username>%EMAILADDRESS%</username>
          </incomingServer>
          <incomingServer type="imap">
            <hostname>#{host}</hostname><port>#{port}</port><socketType>#{socket_type}</socketType>
            <username>#{username}</username>
          </incomingServer>
        </emailProvider>
      </clientConfig>
    XML
  end

  def detect(pages: {}, zone: {}, endpoints: {}, email: EMAIL, password: "secret")
    autoconfig(pages) do
      dns(zone) do
        imap(endpoints) { Imap::Autodetect.call(email: email, password: password) }
      end
    end
  end

  test "takes the settings from the ISPDB and confirms them with a login" do
    result = detect(
      pages: { ISPDB => client_config("imap.example.com", 993) },
      endpoints: { [ "imap.example.com", 993 ] => { accepts: [ EMAIL ] } }
    )

    assert result.success?
    assert_equal "imap.example.com", result.host
    assert_equal 993, result.port
    assert_equal :ssl, result.tls
    assert result.ssl?
    assert_equal EMAIL, result.username
    assert_equal :autoconfig, result.source
  end

  test "logs in with the local part when autoconfig asks for it" do
    result = detect(
      pages: { ISPDB => client_config("imap.example.com", 993, username: "%EMAILLOCALPART%") },
      endpoints: { [ "imap.example.com", 993 ] => { accepts: [ "bob" ] } }
    )

    assert_equal "bob", result.username
    assert_equal :autoconfig, result.source
  end

  test "falls back to the document the domain serves itself, including STARTTLS on 143" do
    result = detect(
      pages: { PROVIDER_DOC => client_config("mailhost.example.com", 143, socket_type: "STARTTLS") },
      endpoints: { [ "mailhost.example.com", 143 ] => { accepts: [ EMAIL ], starttls: true } }
    )

    assert_equal "mailhost.example.com", result.host
    assert_equal :starttls, result.tls
    assert_not result.ssl?
    assert_equal :autoconfig, result.source
  end

  test "uses an SRV record when no autoconfig document exists" do
    result = detect(
      zone: { "_imaps._tcp.example.com" => { Resolv::DNS::Resource::IN::SRV => [ srv("imap.provider.net", 993) ] } },
      endpoints: { [ "imap.provider.net", 993 ] => { accepts: [ EMAIL ] } }
    )

    assert_equal "imap.provider.net", result.host
    assert_equal 993, result.port
    assert_equal :srv, result.source
  end

  test "prefers the lowest-priority SRV target" do
    zone = {
      "_imaps._tcp.example.com" => {
        Resolv::DNS::Resource::IN::SRV => [ srv("backup.provider.net", 993, priority: 20), srv("main.provider.net", 993, priority: 5) ]
      }
    }
    endpoints = {
      [ "main.provider.net", 993 ] => { accepts: [ EMAIL ] },
      [ "backup.provider.net", 993 ] => { accepts: [ EMAIL ] }
    }

    assert_equal "main.provider.net", detect(zone: zone, endpoints: endpoints).host
  end

  test "guesses mail.<domain> when nothing is published" do
    result = detect(endpoints: { [ "mail.example.com", 993 ] => { accepts: [ "bob" ] } })

    assert_equal "mail.example.com", result.host
    assert_equal "bob", result.username
    assert_equal :guess, result.source
  end

  test "derives a guess from the MX record of the domain" do
    result = detect(
      zone: { "example.com" => { Resolv::DNS::Resource::IN::MX => [ mx("mx1.hosting.net") ] } },
      endpoints: { [ "imap.hosting.net", 993 ] => { accepts: [ EMAIL ] } }
    )

    assert_equal "imap.hosting.net", result.host
    assert_equal :guess, result.source
  end

  test "reports auth_failed when the server is found but turns the login down" do
    result = detect(
      pages: { ISPDB => client_config("imap.example.com", 993) },
      endpoints: { [ "imap.example.com", 993 ] => { accepts: [] } }
    )

    assert_not result.success?
    assert_equal :auth_failed, result.reason
    assert_match(/AUTHENTICATIONFAILED/, result.raw_response)
    assert_nil result.host
  end

  test "reports imap_disabled when the refusal says IMAP is switched off" do
    result = detect(
      pages: { ISPDB => client_config("imap.example.com", 993) },
      endpoints: { [ "imap.example.com", 993 ] => { accepts: [], refusal: "[ALERT] IMAP access is disabled for your account" } }
    )

    assert_equal :imap_disabled, result.reason
  end

  test "reports no_server_found when nothing answers anywhere" do
    result = detect

    assert_not result.success?
    assert_equal :no_server_found, result.reason
  end

  test "will not fall back to plaintext when the server cannot upgrade" do
    result = detect(endpoints: { [ "mail.example.com", 143 ] => { accepts: [ EMAIL ], starttls: false } })

    assert_equal :no_server_found, result.reason
  end

  test "reports timeout when detection runs past its budget" do
    slow = ->(**_arguments) { sleep 1 }

    result = replace_singleton(Imap::Autodetect::AutoconfigLookup, :call, slow) do
      Imap::Autodetect.call(email: EMAIL, password: "secret", budget: 0.05)
    end

    assert_equal :timeout, result.reason
  end

  test "reports no_server_found for an address with no domain to work from" do
    assert_equal :no_server_found, Imap::Autodetect.call(email: "not-an-address", password: "secret").reason
  end
end
