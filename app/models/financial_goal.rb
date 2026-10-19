class FinancialGoal < ApplicationRecord
  CATEGORIES = %w[retirement education emergency major_purchase other].freeze
  CURRENCIES = %w[USD EUR GBP].freeze
  STATUSES = %w[active archived].freeze
  MAX_AMOUNT_CENTS = 1_000_000_000_000

  belongs_to :client
  has_many :goal_contributions, dependent: :restrict_with_error

  validates :name, presence: true, length: { maximum: 120 }
  validates :category, inclusion: { in: CATEGORIES }
  validates :currency, inclusion: { in: CURRENCIES }
  validates :status, inclusion: { in: STATUSES }
  validates :target_amount_cents, numericality: {
    only_integer: true, greater_than: 0, less_than_or_equal_to: MAX_AMOUNT_CENTS
  }
  validates :target_date, presence: true
  validate :future_target_date
  validate :currency_without_contributions

  def progress
    contributed = goal_contributions.sum(:amount_cents)
    {
      contributed_amount_cents: contributed,
      remaining_amount_cents: [target_amount_cents - contributed, 0].max,
      progress_percent: (contributed.to_d / target_amount_cents * 100).round(2).to_f
    }
  end

  private

  def future_target_date
    if target_date && (new_record? || will_save_change_to_target_date?) && target_date <= Date.current
      errors.add(:target_date, "must be in the future")
    end
  end

  def currency_without_contributions
    if persisted? && will_save_change_to_currency? && goal_contributions.exists?
      errors.add(:currency, "cannot change after contributions have been recorded")
    end
  end
end
