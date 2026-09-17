# Czech and English. An explicit ?locale= choice sticks in the session; otherwise the
# browser's Accept-Language decides, falling back to English.
module Localization
  extend ActiveSupport::Concern

  included do
    around_action :switch_locale
  end

  private
    def switch_locale(&action)
      I18n.with_locale(resolve_locale, &action)
    end

    def resolve_locale
      if available_locale?(params[:locale])
        session[:locale] = params[:locale]
      elsif available_locale?(session[:locale])
        session[:locale]
      else
        locale_from_accept_language || I18n.default_locale
      end
    end

    def locale_from_accept_language
      request.headers["Accept-Language"].to_s.scan(/([a-z]{2})(?:-[A-Za-z]{2})?/i).flatten
        .map(&:downcase).find { |code| available_locale?(code) }
    end

    def available_locale?(code)
      code.present? && I18n.available_locales.map(&:to_s).include?(code.to_s)
    end
end
