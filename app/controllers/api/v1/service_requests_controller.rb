module Api
  module V1
    class ServiceRequestsController < ClientResourcesController
      def index
        scope = @client.service_requests
        if params.key?(:status)
          unless ServiceRequest::TRANSITIONS.key?(params[:status])
            render json: { errors: { status: ["is not included in the list"] } }, status: :bad_request
            return
          end
          scope = scope.where(status: params[:status])
        end
        render_page(scope)
      end

      def show
        render json: @client.service_requests.find(params[:id])
      end

      def create
        request = @client.service_requests.create!(request_params.except(:status, :resolution_summary))
        render json: request, status: :created
      end

      def update
        request = @client.service_requests.find(params[:id])
        request.with_lock { request.update!(request_params) }
        render json: request
      end

      private

      def request_params
        resource_params(:service_request, :subject, :category, :priority, :description, :status, :resolution_summary)
      end
    end
  end
end
