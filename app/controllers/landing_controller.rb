class LandingController < ApplicationController
  layout "landing"

  skip_before_action :require_pin

  def show
  end
end
