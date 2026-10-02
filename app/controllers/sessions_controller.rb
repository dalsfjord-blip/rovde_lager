class SessionsController < ApplicationController
  skip_before_action :require_pin, only: [ :new, :create, :vipps_login, :vipps_callback, :failure ]

  def new
    render :new, layout: "login"
  end

  def create
    valid_pin = ENV["TABLET_PASSCODE"] ||
      Rails.application.credentials.tablet_passcode ||
      ("1234" if Rails.env.development? || Rails.env.test?)

    if valid_pin.present? && ActiveSupport::SecurityUtils.secure_compare(params[:pin].to_s, valid_pin)
      session[:authenticated] = true
      session.delete(:vipps_payment_url)
      session.delete(:vipps_reference)
      start_agreement
      redirect_to storage_items_path, notice: "Innlogget!"
    else
      flash.now[:alert] = "Feil PIN-kode"
      render :new, layout: "login", status: :unauthorized
    end
  end

  def vipps_login
    state = SecureRandom.urlsafe_base64(32)
    code_verifier = SecureRandom.urlsafe_base64(64)
    session[:vipps_login_state] = state
    session[:vipps_login_code_verifier] = code_verifier

    redirect_to VippsLoginClient.new.authorization_url(
      state: state,
      code_verifier: code_verifier,
      redirect_uri: vipps_login_redirect_uri
    ), allow_other_host: true
  rescue VippsLoginClient::ConfigurationError
    redirect_to harbor_rental_login_path, alert: "Vipps Login er ikkje konfigurert enno."
  end

  def vipps_callback
    unless valid_vipps_login_state?
      clear_vipps_login_session
      redirect_to harbor_rental_login_path, alert: "Innlogginga kunne ikkje stadfestast. Prøv på nytt."
      return
    end

    profile = VippsLoginClient.new.profile(
      code: params[:code],
      code_verifier: session[:vipps_login_code_verifier],
      redirect_uri: vipps_login_redirect_uri
    )
    user = find_or_create_vipps_user(profile)
    session[:user_id] = user.id
    clear_vipps_login_session
    redirect_to harbor_rental_path, notice: "Du er no logga inn med Vipps."
  rescue VippsLoginClient::ConfigurationError, VippsLoginClient::RequestError, ActiveRecord::RecordInvalid
    clear_vipps_login_session
    redirect_to harbor_rental_login_path, alert: "Vipps-innlogginga vart ikkje fullført. Prøv på nytt."
  end

  def failure
    clear_vipps_login_session
    redirect_to harbor_rental_login_path, alert: "Vipps-innlogginga vart avbroten eller mislukkast."
  end

  def destroy
    session.delete(:authenticated)
    session.delete(:user_id)
    session.delete(:vipps_payment_url)
    session.delete(:vipps_reference)
    clear_vipps_login_session
    start_agreement
    redirect_to root_path, notice: "Logget ut"
  end

  private

  def vipps_login_redirect_uri
    VippsLoginClient.new.redirect_uri(default: vipps_callback_url)
  end

  def valid_vipps_login_state?
    params[:code].present? && params[:state].present? &&
      session[:vipps_login_state].present? &&
      ActiveSupport::SecurityUtils.secure_compare(params[:state], session[:vipps_login_state])
  end

  def find_or_create_vipps_user(profile)
    user = User.find_by(phone_number: normalized_phone_number(profile[:phone_number])) if profile[:phone_number].present?
    user ||= User.find_by(email: profile[:email])
    user ||= User.new
    user.assign_attributes(profile)
    user.save!
    user
  end

  def normalized_phone_number(phone_number)
    phone_number.to_s.gsub(/\D/, "").presence
  end

  def clear_vipps_login_session
    session.delete(:vipps_login_state)
    session.delete(:vipps_login_code_verifier)
  end
end
