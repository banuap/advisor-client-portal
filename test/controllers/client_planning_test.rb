require_relative "../test_helper"

class ClientPlanningTest < ActionDispatch::IntegrationTest
  setup do
    @client = Client.create!(external_reference: "demo-owner", display_name: "Synthetic Owner", risk_profile: "moderate")
    @other_client = Client.create!(external_reference: "demo-other", display_name: "Synthetic Other", risk_profile: "growth")
    @base = "/api/v1/clients/#{@client.external_reference}"
    @goal_attributes = {
      name: "Demo reserve", category: "emergency", target_amount_cents: 100_00,
      currency: "USD", target_date: (Date.current + 365).iso8601
    }
    @goal = @client.financial_goals.create!(@goal_attributes)
  end

  test "create and show goal expose exact progress without accepting ownership or initial status" do
    post "#{@base}/financial_goals", params: {
      financial_goal: @goal_attributes.merge(client_id: @other_client.id, status: "archived", contributed_amount_cents: 500_00)
    }, as: :json
    assert_response :created
    goal = response.parsed_body
    assert_equal @client.id, goal["client_id"]
    assert_equal "active", goal["status"]
    assert_equal 0, goal["contributed_amount_cents"]
    get "#{@base}/financial_goals/#{goal['id']}"
    assert_response :success
    assert_equal 100_00, response.parsed_body["remaining_amount_cents"]
  end

  test "updating a goal preserves its client and exposes validation errors" do
    patch "#{@base}/financial_goals/#{@goal.id}", params: {
      financial_goal: { name: "New demo name", client_id: @other_client.id }
    }, as: :json
    assert_response :success
    assert_equal "New demo name", @goal.reload.name
    assert_equal @client.id, @goal.client_id
    patch "#{@base}/financial_goals/#{@goal.id}", params: { financial_goal: { target_amount_cents: -1 } }, as: :json
    assert_response :unprocessable_entity
    assert response.parsed_body["errors"]["target_amount_cents"].present?
    assert_equal 100_00, @goal.reload.target_amount_cents
  end

  test "goal lists are client scoped and paginated without changing existing client response shapes" do
    @other_client.financial_goals.create!(@goal_attributes)
    get "#{@base}/financial_goals", params: { page: 1, per_page: 1 }
    assert_response :success
    body = response.parsed_body
    assert_equal [@goal.id], body["items"].map { |goal| goal["id"] }
    assert_equal({ "page" => 1, "per_page" => 1, "total" => 1 }, body["pagination"])
    get "#{@base}/financial_goals", params: { page: 2, per_page: 1 }
    assert_equal [], response.parsed_body["items"]
    get "/api/v1/clients"
    assert_response :success
    assert_kind_of Array, response.parsed_body
    get @base
    assert_response :success
    assert_equal @client.external_reference, response.parsed_body["external_reference"]
  end

  test "invalid pagination returns a clear bad request" do
    [{ page: 0 }, { page: -1 }, { page: "abc" }, { page: "1.5" }, { page: 1_000_000 },
      { per_page: 0 }, { per_page: 101 }, { per_page: "all" }].each do |query|
      get "#{@base}/financial_goals", params: query
      assert_response :bad_request
      assert response.parsed_body["errors"]["pagination"].present?
    end
  end

  test "contributions record demo progress and reject duplicates without changing totals" do
    url = "#{@base}/financial_goals/#{@goal.id}/goal_contributions"
    data = { external_reference: "demo-contribution-1", amount_cents: 25_00, contributed_on: Date.current.iso8601 }
    post url, params: { goal_contribution: data.merge(financial_goal_id: 999) }, as: :json
    assert_response :created
    assert_equal @goal.id, response.parsed_body["contribution"]["financial_goal_id"]
    assert_equal 25.0, response.parsed_body["progress"]["progress_percent"]
    assert_no_difference("GoalContribution.count") do
      post url, params: { goal_contribution: data }, as: :json
    end
    assert_response :unprocessable_entity
    assert response.parsed_body["errors"]["external_reference"].present?
    assert_equal 25_00, @goal.progress[:contributed_amount_cents]
    get url
    assert_response :success
    assert_equal 1, response.parsed_body["pagination"]["total"]
  end

  test "archiving a goal prevents further contributions and currency changes after recording fail" do
    @goal.goal_contributions.create!(external_reference: "demo-ledger", amount_cents: 1, contributed_on: Date.current)
    patch "#{@base}/financial_goals/#{@goal.id}", params: { financial_goal: { currency: "EUR" } }, as: :json
    assert_response :unprocessable_entity
    patch "#{@base}/financial_goals/#{@goal.id}", params: { financial_goal: { status: "archived" } }, as: :json
    assert_response :success
    assert_no_difference("GoalContribution.count") do
      post "#{@base}/financial_goals/#{@goal.id}/goal_contributions", params: {
        goal_contribution: { external_reference: "demo-blocked", amount_cents: 1, contributed_on: Date.current.iso8601 }
      }, as: :json
    end
    assert_response :unprocessable_entity
  end

  test "nested goal and contribution paths never select another client's resource" do
    other_base = "/api/v1/clients/#{@other_client.external_reference}/financial_goals/#{@goal.id}"
    get other_base
    assert_response :not_found
    patch other_base, params: { financial_goal: { name: "Wrong owner" } }, as: :json
    assert_response :not_found
    get "#{other_base}/goal_contributions"
    assert_response :not_found
    post "#{other_base}/goal_contributions", params: {
      goal_contribution: { external_reference: "demo-cross-client", amount_cents: 1, contributed_on: Date.current.iso8601 }
    }, as: :json
    assert_response :not_found
    get "/api/v1/clients/not-a-client/financial_goals"
    assert_response :not_found
    assert_equal "Demo reserve", @goal.reload.name
  end

  test "overview aggregates only active goals and separates currency totals" do
    @goal.goal_contributions.create!(external_reference: "demo-summary", amount_cents: 10_00, contributed_on: Date.current)
    @client.financial_goals.create!(@goal_attributes.merge(currency: "EUR", target_amount_cents: 200_00))
    archived = @client.financial_goals.create!(@goal_attributes)
    archived.goal_contributions.create!(external_reference: "demo-archived", amount_cents: 50_00, contributed_on: Date.current)
    archived.update!(status: "archived")
    @other_client.financial_goals.create!(@goal_attributes.merge(target_amount_cents: 999_00))
    @client.service_requests.create!(subject: "Demo support", category: "general", description: "Synthetic request")
    cancelled = @client.service_requests.create!(subject: "Demo cancelled", category: "general", description: "Synthetic request")
    cancelled.update!(status: "cancelled")
    get "#{@base}/overview"
    assert_response :success
    body = response.parsed_body
    assert_equal true, body["synthetic_data_only"]
    assert_equal 2, body["active_goal_count"]
    currencies = body["goals_by_currency"].index_by { |item| item["currency"] }
    assert_equal 100_00, currencies["USD"]["target_amount_cents"]
    assert_equal 10_00, currencies["USD"]["contributed_amount_cents"]
    assert_equal 200_00, currencies["EUR"]["target_amount_cents"]
    assert_equal 0, currencies["EUR"]["contributed_amount_cents"]
    assert_equal 1, body["open_service_request_count"]
    assert_equal({ "open" => 1, "cancelled" => 1 }, body["service_request_counts"])
    assert_equal "pending", body["client"]["onboarding_status"]
  end

  test "overview for an empty client has explicit zero counts and empty totals" do
    get "/api/v1/clients/#{@other_client.external_reference}/overview"
    assert_response :success
    body = response.parsed_body
    assert_equal 0, body["active_goal_count"]
    assert_equal [], body["goals_by_currency"]
    assert_equal({}, body["service_request_counts"])
    assert_equal 0, body["open_service_request_count"]
  end

  test "invalid goal input and missing or malformed request envelopes fail without writing" do
    assert_no_difference("FinancialGoal.count") do
      post "#{@base}/financial_goals", params: { financial_goal: @goal_attributes.merge(target_date: "not-a-date") }, as: :json
    end
    assert_response :unprocessable_entity
    assert response.parsed_body["errors"]["target_date"].present?

    {
      "#{@base}/financial_goals" => :financial_goal,
      "#{@base}/financial_goals/#{@goal.id}/goal_contributions" => :goal_contribution,
      "#{@base}/service_requests" => :service_request
    }.each do |url, envelope|
      [{}, { envelope => "not-an-object" }, { envelope => ["not-an-object"] }].each do |payload|
        post url, params: payload, as: :json
        assert_response :bad_request
      end
    end
  end
end
