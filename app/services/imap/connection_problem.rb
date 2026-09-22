module Imap
  # Turns a failed Imap::Autodetect into what the person should do about it, in their
  # provider's words. What we know about each provider lives in config/imap_providers.yml and
  # the copy in the imap_problems locale scope; this only decides which message applies.
  #
  #   Imap::ConnectionProblem.call(reason: :auth_failed, email: "bob@icloud.com")
  #   #=> #<Problem key=:app_password provider="iCloud" message="iCloud does not accept ...">
  class ConnectionProblem
    PROVIDERS = Rails.root.join("config/imap_providers.yml").then { |path| YAML.safe_load_file(path) }.freeze
    GENERIC = { no_server_found: :unknown_host, timeout: :timeout, auth_failed: :wrong_password, imap_disabled: :imap_disabled }.freeze
    # Some servers name the fix themselves, whichever provider they are.
    APP_PASSWORD_HINT = /app(lication)?[- ]specific password|app password/i

    Problem = Struct.new(:key, :provider, :message, :guide, keyword_init: true) do
      # The "Show me how" link target; nil until the provider has a guide.
      def guide?
        guide.present?
      end
    end

    def self.call(reason:, email:, raw_response: nil)
      new(reason: reason, email: email, raw_response: raw_response).call
    end

    # The "Show me how" target for this email's provider, nil until a guide exists for it.
    # Needs only the address, not a failure reason, so a view can offer it before anything
    # has gone wrong.
    def self.guide_for(email)
      provider_for(email)&.fetch("guide")
    end

    def self.provider_for(email)
      domain = email.to_s.split("@").last.to_s.strip.downcase
      PROVIDERS.values.find { |entry| entry.fetch("domains").include?(domain) }
    end

    def initialize(reason:, email:, raw_response: nil)
      @reason = reason.to_sym
      @email = email.to_s
      @raw_response = raw_response.to_s
    end

    def call
      key = provider_key || hinted_key || GENERIC.fetch(reason, :unknown_host)
      name = provider&.fetch("name")

      Problem.new(key: key, provider: name, guide: provider&.fetch("guide"), message: I18n.t("imap_problems.#{key}", provider: name))
    end

    private

    attr_reader :reason, :email, :raw_response

    def provider_key
      messages = provider&.fetch("messages")
      (messages&.fetch(reason.to_s, nil) || messages&.fetch("any", nil))&.to_sym
    end

    def hinted_key
      :app_password_generic if reason == :auth_failed && raw_response.match?(APP_PASSWORD_HINT)
    end

    def provider
      return @provider if defined?(@provider)

      @provider = self.class.provider_for(email)
    end
  end
end
