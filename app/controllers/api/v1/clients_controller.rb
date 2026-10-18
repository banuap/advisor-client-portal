module Api
  module V1
    class ClientsController < ApplicationController
      def index
        render json: Client.order(:external_reference)
      end

      def show
        client = Client.find_by(external_reference: params[:id])
        return head :not_found unless client

        render json: client
      end

      def create
        client = Client.new(client_params)
        if client.save
          render json: client, status: :created
        else
          render json: { errors: client.errors.to_hash }, status: :unprocessable_entity
        end
      end

      private

      def client_params
        params.require(:client).permit(:external_reference, :display_name, :risk_profile)
      end
    end
  end
end
