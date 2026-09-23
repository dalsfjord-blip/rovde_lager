module Api
  class BrregLookupsController < ApplicationController
    skip_before_action :require_pin, only: [ :index, :show ]
    skip_before_action :verify_authenticity_token, only: [ :index, :show ]

    def index
      render json: BrregClient.new.search(params[:name])
    end

    def show
      result = BrregClient.new.lookup(params[:organization_number])
      render json: result || {}, status: result ? :ok : :not_found
    end
  end
end
