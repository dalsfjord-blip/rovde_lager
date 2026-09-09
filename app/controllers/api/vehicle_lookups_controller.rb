module Api
  class VehicleLookupsController < ApplicationController
    skip_before_action :require_pin, only: [:show]
    skip_before_action :verify_authenticity_token, only: [:show]

    def show
      service = VehicleLookupService.new
      result = service.lookup(params[:registration_number])

      if result
        render json: [result]
      else
        render json: []
      end
    end
  end
end
