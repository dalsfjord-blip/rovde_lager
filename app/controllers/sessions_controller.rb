class SessionsController < ApplicationController
  skip_before_action :require_pin, only: [:new, :create]

  def new
    render :new, layout: "login"
  end

  def create
    valid_pin = ENV["TABLET_PASSCODE"] ||
      Rails.application.credentials.tablet_passcode ||
      ("1234" if Rails.env.development? || Rails.env.test?)

    if valid_pin.present? && ActiveSupport::SecurityUtils.secure_compare(params[:pin].to_s, valid_pin)
      session[:authenticated] = true
      start_agreement
      redirect_to storage_items_path, notice: "Innlogget!"
    else
      flash.now[:alert] = "Feil PIN-kode"
      render :new, layout: "login", status: :unauthorized
    end
  end

  def destroy
    session.delete(:authenticated)
    start_agreement
    redirect_to login_path, notice: "Logget ut"
  end
end
