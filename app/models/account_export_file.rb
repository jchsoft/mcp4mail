# frozen_string_literal: true

# A finished export waiting to be fetched, for the case where building it took too long to hand
# back in the request. The row holds the JSON and the digest of the one-time token that appears
# in the emailed link - the same shape as attachment downloads, where the token in the URL is the
# whole credential and no session cookie is needed.
class AccountExportFile < ApplicationRecord
  EXPIRES_IN = 24.hours

  belongs_to :user

  # Returned once, by start!, and never stored: the row keeps only its digest.
  attr_accessor :raw_token

  scope :live, -> { where(expires_at: Time.current..) }

  def self.start!(user)
    raw_token = SecureRandom.urlsafe_base64(32)
    create!(user: user, token_digest: digest(raw_token), expires_at: EXPIRES_IN.from_now)
      .tap { |export| export.raw_token = raw_token }
  end

  # The export behind a link someone followed, or nil: expired, already swept, or a token that
  # was never ours. A row whose job has not finished yet has no payload and is not one either.
  def self.find_ready(raw_token)
    return nil if raw_token.blank?

    live.where.not(payload: nil).find_by(token_digest: digest(raw_token))
  end

  def self.sweep(now: Time.current)
    where(expires_at: ...now).delete_all
  end

  def self.digest(raw_token) = Digest::SHA256.hexdigest(raw_token)

  def store!(json)
    update!(payload: json)
  end
end
