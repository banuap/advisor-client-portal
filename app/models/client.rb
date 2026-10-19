class Client < ApplicationRecord
  has_many :financial_goals, dependent: :restrict_with_error
  has_many :service_requests, dependent: :restrict_with_error

  RISK_PROFILES = %w[conservative moderate growth].freeze

  validates :external_reference, presence: true, uniqueness: true
  validates :display_name, presence: true, length: { maximum: 120 }
  validates :risk_profile, inclusion: { in: RISK_PROFILES }
  validates :onboarding_status, inclusion: { in: %w[pending] }
end
