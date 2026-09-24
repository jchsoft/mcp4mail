module MailAccountsHelper
  # Which badge an audit event wears in the activity list. The list is read to answer
  # one question - did the AI get what it asked for? - so the two answers to it are
  # coloured and everything in between stays neutral: a limit the caller hit, or a
  # draft the owner themselves sent or threw away.
  OUTCOME_BADGE_VARIANTS = {
    "ok" => :ok, "sent" => :ok,
    "denied" => :denied, "error" => :denied
  }.freeze

  def outcome_badge_variant(outcome) = OUTCOME_BADGE_VARIANTS.fetch(outcome, :neutral)
end
