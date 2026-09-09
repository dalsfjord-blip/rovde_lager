class SessionsController < ApplicationController
  skip_before_action :require_pin, only: [:new, :create]

  def new
    render :new, layout: "login"
  end

  def create
    if params[:pin] == ENV["TABLET_PASSCODE"] ||
       (Rails.application.credentials.respond_to?(:tablet_passcode) && params[:pin] == Rails.application.credentials.tablet_passcode)
      session[:authenticated] = true
      redirect_to storage_items_path, notice: "Innlogget!"
    else
      flash.now[:alert] = "Feil PIN-kode"
      render :new, layout: "login", status: :unauthorized
    end
  end

  def destroy
    session[:authenticated] = false
    redirect_to login_path, notice: "Logget ut"
  end
end
