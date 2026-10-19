require_relative "../test_helper"

class GoalContributionTest < ActiveSupport::TestCase
  setup do
    client = Client.create!(external_reference: "demo-contributor", display_name: "Synthetic Client", risk_profile: "growth")
    @goal = client.financial_goals.create!(
      name: "Demo education", category: "education", target_amount_cents: 100_00,
      currency: "GBP", target_date: Date.current + 365
    )
    @attributes = { external_reference: "demo-contribution-001", amount_cents: 10_00, contributed_on: Date.current }
  end

  test "requires a positive integral amount within the supported range and a nonfuture date" do
    invalid = {
      amount_cents: [nil, 0, -1, 0.5, "12.5", 1_000_000_000_001],
      contributed_on: [nil, "invalid-date", Date.tomorrow],
      external_reference: ["", "x" * 121]
    }
    invalid.each do |field, values|
      values.each do |value|
        contribution = @goal.goal_contributions.new(@attributes.merge(field => value))
        assert_not contribution.valid?, "#{field}=#{value.inspect} must fail"
        assert contribution.errors[field].present?
      end
    end
  end

  test "duplicate references fail within one goal but may be used on a different goal" do
    @goal.goal_contributions.create!(@attributes)
    duplicate = @goal.goal_contributions.new(@attributes)
    assert_not duplicate.valid?
    assert duplicate.errors[:external_reference].present?
    other_goal = @goal.client.financial_goals.create!(
      name: "Second demo goal", category: "retirement", target_amount_cents: 200_00,
      currency: "GBP", target_date: Date.current + 365
    )
    assert other_goal.goal_contributions.new(@attributes).valid?
  end

  test "archived goals reject contributions" do
    @goal.update!(status: "archived")
    contribution = @goal.goal_contributions.new(@attributes)
    assert_not contribution.save
    assert contribution.errors[:financial_goal].present?
    assert_equal 0, @goal.goal_contributions.count
  end
end
