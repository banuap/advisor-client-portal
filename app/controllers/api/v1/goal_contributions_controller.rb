module Api
  module V1
    class GoalContributionsController < ClientResourcesController
      before_action :load_goal

      def index
        render_page(@goal.goal_contributions)
      end

      def create
        contribution = nil
        @goal.with_lock do
          contribution = @goal.goal_contributions.create!(contribution_params)
        end
        render json: { contribution: contribution, progress: @goal.progress }, status: :created
      end

      private

      def load_goal
        @goal = @client.financial_goals.find(params[:financial_goal_id])
      end

      def contribution_params
        resource_params(:goal_contribution, :external_reference, :amount_cents, :contributed_on)
      end
    end
  end
end
