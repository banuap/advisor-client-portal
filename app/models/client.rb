class Client < ApplicationRecord
  RISK_PROFILES = %w[conservative moderate growth].freeze

  validates :external_reference, presence: true, uniqueness: true
  validates :display_name, presence: true, length: { maximum: 120 }
  validates :risk_profile, inclusion: { in: RISK_PROFILES }
  validates :onboarding_status, inclusion: { in: %w[pending] }
end
