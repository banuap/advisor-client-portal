class GoalContribution < ApplicationRecord
  belongs_to :financial_goal

  validates :external_reference, presence: true, length: { maximum: 120 },
    uniqueness: { scope: :financial_goal_id }
  validates :amount_cents, numericality: {
    only_integer: true, greater_than: 0, less_than_or_equal_to: FinancialGoal::MAX_AMOUNT_CENTS
  }
  validates :contributed_on, presence: true
  validate :not_future_dated
  validate :active_goal

  private

  def not_future_dated
    errors.add(:contributed_on, "cannot be in the future") if contributed_on && contributed_on > Date.current
  end

  def active_goal
    if financial_goal && financial_goal.status != "active"
      errors.add(:financial_goal, "must be active to record a contribution")
    end
  end
end
