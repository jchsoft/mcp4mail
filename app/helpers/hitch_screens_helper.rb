# The consent and device-activation screens are hitch-rails' controllers
# rendering our own templates (app/views/hitch/). The gem hands those templates
# English literals in two places - the activation alerts and the scope tokens -
# and these turn both into translated copy.
module HitchScreensHelper
  # The gem's controller sets @alert to one of a handful of fixed sentences.
  # Anything it adds in a later version falls through untranslated rather than
  # disappearing.
  HITCH_ACTIVATION_ALERTS = {
    "Enter the code your device is showing." => "blank_code",
    "Something went wrong with that submission. Enter the code again." => "bad_submission",
    "Too many attempts. Wait a minute and try again." => "too_many_attempts",
    "Code entry is temporarily unavailable. Try again shortly." => "unavailable",
    "That code isn't waiting for approval. It may have expired or already been used — ask your device for a fresh one." => "unknown_code"
  }.freeze

  def hitch_activation_alert(alert)
    key = HITCH_ACTIVATION_ALERTS[alert]
    key ? t("hitch.activation_alerts.#{key}") : alert
  end

  # What a scope lets the client do, in words; nil for a scope we have no
  # sentence for, so the screen still shows the bare token.
  def hitch_scope_description(scope)
    t("hitch.scopes.#{scope}", default: nil) if scope.match?(/\A[a-z_]+\z/)
  end
end
