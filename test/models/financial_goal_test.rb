require_relative "../test_helper"

class FinancialGoalTest < ActiveSupport::TestCase
  setup do
    @client = Client.create!(external_reference: "demo-planning", display_name: "Synthetic Planner", risk_profile: "moderate")
    @attributes = {
      name: "Demo emergency fund", category: "emergency", target_amount_cents: 100_00,
      currency: "USD", target_date: Date.current + 365
    }
  end

  test "creates an active goal with zero progress" do
    goal = @client.financial_goals.create!(@attributes)
    assert_equal "active", goal.status
    assert_equal({ contributed_amount_cents: 0, remaining_amount_cents: 100_00, progress_percent: 0.0 }, goal.progress)
  end

  test "requires valid goal attributes and a future target date" do
    invalid = {
      name: ["", "x" * 121], category: ["unsupported"], currency: ["JPY"],
      status: ["completed"], target_date: [nil, "not-a-date", Date.current, Date.yesterday],
      target_amount_cents: [nil, 0, -1, 1.5, "1.25", 1_000_000_000_001, "not-money"]
    }
    invalid.each do |field, values|
      values.each do |value|
        goal = @client.financial_goals.new(@attributes.merge(field => value))
        assert_not goal.valid?, "#{field}=#{value.inspect} must fail"
        assert goal.errors[field].present?
      end
    end
    assert @client.financial_goals.new(@attributes.merge(target_amount_cents: FinancialGoal::MAX_AMOUNT_CENTS)).valid?
  end

  test "progress uses contribution totals and does not create a negative remainder when overfunded" do
    goal = @client.financial_goals.create!(@attributes)
    goal.goal_contributions.create!(external_reference: "demo-payment-1", amount_cents: 25_00, contributed_on: Date.current)
    assert_equal 25.0, goal.progress[:progress_percent]
    goal.goal_contributions.create!(external_reference: "demo-payment-2", amount_cents: 100_00, contributed_on: Date.current)
    assert_equal 125_00, goal.progress[:contributed_amount_cents]
    assert_equal 125.0, goal.progress[:progress_percent]
    assert_equal 0, goal.progress[:remaining_amount_cents]
  end

  test "currency is editable before contributions but cannot reinterpret recorded amounts" do
    goal = @client.financial_goals.create!(@attributes)
    goal.update!(currency: "EUR")
    goal.goal_contributions.create!(external_reference: "demo-payment", amount_cents: 1, contributed_on: Date.current)
    assert_not goal.update(currency: "GBP")
    assert goal.errors[:currency].present?
    assert_equal "EUR", goal.reload.currency
  end

  test "an elapsed target date does not prevent unrelated edits or archiving" do
    goal = @client.financial_goals.create!(@attributes.merge(target_date: Date.tomorrow))
    travel_to 3.days.from_now do
      assert goal.update(name: "Renamed demo goal", status: "archived")
      assert_not goal.update(target_date: Date.yesterday)
    end
  end

  test "goals cannot be deleted when they have contribution records" do
    goal = @client.financial_goals.create!(@attributes)
    goal.goal_contributions.create!(external_reference: "demo-payment", amount_cents: 1, contributed_on: Date.current)
    assert_not goal.destroy
    assert FinancialGoal.exists?(goal.id)
  end
end
