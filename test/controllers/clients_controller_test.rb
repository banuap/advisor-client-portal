require_relative "../test_helper"

class ClientsControllerTest < ActionDispatch::IntegrationTest
  test "creates a client with pending onboarding status" do
    post "/api/v1/clients", params: {
      client: {
        external_reference: "demo-client-003",
        display_name: "Synthetic Demo Client",
        risk_profile: "growth"
      }
    }

    assert_response :created
    assert_equal "pending", response.parsed_body["onboarding_status"]
  end

  test "does not allow a caller to set onboarding status" do
    post "/api/v1/clients", params: {
      client: {
        external_reference: "demo-client-004",
        display_name: "Synthetic Demo Client",
        risk_profile: "growth",
        onboarding_status: "approved"
      }
    }

    assert_response :created
    assert_equal "pending", response.parsed_body["onboarding_status"]
  end
end
