require_relative "../test_helper"

class ServiceRequestTest < ActiveSupport::TestCase
  setup do
    @client = Client.create!(external_reference: "demo-service", display_name: "Synthetic Client", risk_profile: "conservative")
    @attributes = { subject: "Review demo goal", category: "financial_planning", description: "Discuss a synthetic plan." }
  end

  test "new requests default to open and normal priority" do
    request = @client.service_requests.create!(@attributes)
    assert_equal "open", request.status
    assert_equal "normal", request.priority
    assert_nil request.resolved_at
  end

  test "request fields and length limits are enforced" do
    {
      subject: ["", "x" * 161], description: ["", "x" * 4001],
      category: ["trading"], priority: ["urgent"], status: ["resolved", "unknown"],
      resolution_summary: ["premature summary", "x" * 2001]
    }.each do |field, values|
      values.each do |value|
        request = @client.service_requests.new(@attributes.merge(field => value))
        assert_not request.valid?, "#{field}=#{value.inspect} must fail"
      end
    end
  end

  test "only declared status transitions are allowed and resolution requires a summary" do
    request = @client.service_requests.create!(@attributes)
    assert_not request.update(status: "resolved", resolution_summary: "Cannot skip review")
    request.reload
    assert request.update(status: "in_progress")
    assert_not request.update(status: "open")
    request.reload
    assert_not request.update(status: "resolved")
    assert request.errors[:resolution_summary].present?
    request.reload
    assert request.update(status: "resolved", resolution_summary: "Synthetic review completed")
    assert request.resolved_at.present?
    stamp = request.resolved_at
    request.update!(subject: "Clarified demo subject")
    assert_equal stamp, request.resolved_at
    assert_not request.update(status: "in_progress")
  end

  test "cancellation is permitted from open or in progress and is terminal" do
    %w[open in_progress].each do |status|
      request = @client.service_requests.create!(@attributes)
      request.update!(status: status)
      assert request.update(status: "cancelled")
      assert_nil request.resolved_at
      assert_not request.update(status: "open")
    end
  end
end
