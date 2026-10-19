module Api
  module V1
    class FinancialGoalsController < ClientResourcesController
      def index
        render_page(@client.financial_goals)
      end

      def show
        goal = @client.financial_goals.find(params[:id])
        render json: goal.as_json.merge(goal.progress)
      end

      def create
        goal = @client.financial_goals.create!(goal_params.except(:status))
        render json: goal.as_json.merge(goal.progress), status: :created
      end

      def update
        goal = @client.financial_goals.find(params[:id])
        goal.with_lock { goal.update!(goal_params) }
        render json: goal.as_json.merge(goal.progress)
      end

      private

      def goal_params
        resource_params(:financial_goal, :name, :category, :target_amount_cents, :currency, :target_date, :status)
      end
    end
  end
end
