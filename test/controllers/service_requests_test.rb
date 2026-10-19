require_relative "../test_helper"

class ServiceRequestsTest < ActionDispatch::IntegrationTest
  setup do
    @client = Client.create!(external_reference: "demo-request-owner", display_name: "Synthetic Client", risk_profile: "moderate")
    @other = Client.create!(external_reference: "demo-request-other", display_name: "Synthetic Other", risk_profile: "growth")
    @url = "/api/v1/clients/#{@client.external_reference}/service_requests"
    @attributes = { subject: "Demo planning question", category: "financial_planning", description: "Discuss a synthetic goal." }
  end

  test "create defaults lifecycle fields and does not accept ownership or resolution timestamps" do
    post @url, params: { service_request: @attributes.merge(
      client_id: @other.id, status: "resolved", resolution_summary: "Not reviewed", resolved_at: Time.current.iso8601
    ) }, as: :json
    assert_response :created
    body = response.parsed_body
    assert_equal @client.id, body["client_id"]
    assert_equal "open", body["status"]
    assert_nil body["resolution_summary"]
    assert_nil body["resolved_at"]
    assert_equal "pending", @client.reload.onboarding_status
  end

  test "full lifecycle requires review and resolution evidence and cannot reopen terminal requests" do
    request = @client.service_requests.create!(@attributes)
    url = "#{@url}/#{request.id}"
    patch url, params: { service_request: { status: "resolved", resolution_summary: "Cannot skip review" } }, as: :json
    assert_response :unprocessable_entity
    assert_equal "open", request.reload.status
    patch url, params: { service_request: { status: "in_progress", priority: "high" } }, as: :json
    assert_response :success
    assert_equal "high", response.parsed_body["priority"]
    patch url, params: { service_request: { status: "resolved" } }, as: :json
    assert_response :unprocessable_entity
    assert response.parsed_body["errors"]["resolution_summary"].present?
    patch url, params: { service_request: { status: "resolved", resolution_summary: "Synthetic discussion completed" } }, as: :json
    assert_response :success
    assert response.parsed_body["resolved_at"].present?
    patch url, params: { service_request: { status: "open" } }, as: :json
    assert_response :unprocessable_entity
    assert_equal "resolved", request.reload.status
  end

  test "request index supports validated status filters and client-scoped pagination" do
    open_request = @client.service_requests.create!(@attributes)
    cancelled = @client.service_requests.create!(@attributes)
    cancelled.update!(status: "cancelled")
    @other.service_requests.create!(@attributes)
    get @url, params: { status: "open", per_page: 1 }
    assert_response :success
    assert_equal [open_request.id], response.parsed_body["items"].map { |item| item["id"] }
    assert_equal 1, response.parsed_body["pagination"]["total"]
    get @url, params: { status: "unknown" }
    assert_response :bad_request
    assert response.parsed_body["errors"]["status"].present?
    get @url, params: { page: 0 }
    assert_response :bad_request
    get "#{@url}/#{cancelled.id}"
    assert_response :success
    assert_equal "cancelled", response.parsed_body["status"]
  end

  test "requests cannot be read or changed through another client's path" do
    request = @client.service_requests.create!(@attributes)
    other_url = "/api/v1/clients/#{@other.external_reference}/service_requests/#{request.id}"
    get other_url
    assert_response :not_found
    patch other_url, params: { service_request: { status: "cancelled", client_id: @other.id } }, as: :json
    assert_response :not_found
    assert_equal "open", request.reload.status
    assert_equal @client.id, request.client_id
  end

  test "invalid fields return structured errors and missing envelopes are bad requests" do
    assert_no_difference("ServiceRequest.count") do
      post @url, params: { service_request: @attributes.merge(subject: "", category: "unknown") }, as: :json
    end
    assert_response :unprocessable_entity
    assert response.parsed_body["errors"]["subject"].present?
    assert response.parsed_body["errors"]["category"].present?
    post @url, params: {}, as: :json
    assert_response :bad_request
  end
end
