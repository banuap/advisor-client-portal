require_relative "../test_helper"

class ClientTest < ActiveSupport::TestCase
  test "requires a supported risk profile and starts onboarding as pending" do
    client = Client.new(
      external_reference: "demo-client-001",
      display_name: "Synthetic Demo Client",
      risk_profile: "moderate"
    )

    assert client.valid?
    assert_equal "pending", client.onboarding_status
  end

  test "rejects an unsupported risk profile" do
    client = Client.new(
      external_reference: "demo-client-002",
      display_name: "Synthetic Demo Client",
      risk_profile: "speculative"
    )

    assert_not client.valid?
    assert_includes client.errors[:risk_profile], "is not included in the list"
  end
end
