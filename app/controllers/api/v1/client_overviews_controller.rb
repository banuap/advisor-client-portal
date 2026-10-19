module Api
  module V1
    class ClientOverviewsController < ClientResourcesController
      def show
        goals = @client.financial_goals.where(status: "active")
        contributions = GoalContribution.joins(:financial_goal).where(financial_goal: goals)
          .group("financial_goals.currency").sum(:amount_cents)
        render json: {
          client: @client,
          synthetic_data_only: true,
          active_goal_count: goals.count,
          goals_by_currency: goals.group(:currency).sum(:target_amount_cents).map do |currency, target|
            { currency: currency, target_amount_cents: target, contributed_amount_cents: contributions.fetch(currency, 0) }
          end,
          service_request_counts: @client.service_requests.group(:status).count,
          open_service_request_count: @client.service_requests.where(status: %w[open in_progress]).count
        }
      end
    end
  end
end
