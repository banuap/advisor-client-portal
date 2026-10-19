module Api
  module V1
    class ClientResourcesController < ApplicationController
      before_action :load_client

      rescue_from ActiveRecord::RecordNotFound do
        render json: { errors: { resource: ["not found for this client"] } }, status: :not_found
      end
      rescue_from ActiveRecord::RecordInvalid do |error|
        render json: { errors: error.record.errors.to_hash }, status: :unprocessable_entity
      end

      private

      def load_client
        @client = Client.find_by!(external_reference: params[:client_id])
      end

      def resource_params(key, *attributes)
        value = params.require(key)
        raise ActionController::ParameterMissing, key unless value.is_a?(ActionController::Parameters)

        value.permit(*attributes)
      end

      def render_page(scope)
        page = params.fetch(:page, "1").to_s
        per_page = params.fetch(:per_page, "25").to_s
        unless page.match?(/\A[1-9]\d{0,5}\z/) && per_page.match?(/\A[1-9]\d{0,2}\z/) && per_page.to_i <= 100
          render json: { errors: { pagination: ["page must be 1-999999 and per_page must be 1-100"] } },
            status: :bad_request
          return
        end

        render json: {
          items: scope.order(:id).limit(per_page.to_i).offset((page.to_i - 1) * per_page.to_i),
          pagination: { page: page.to_i, per_page: per_page.to_i, total: scope.count }
        }
      end
    end
  end
end
