class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  before_action :require_pin

  private

  def require_pin
    unless session[:authenticated]
      redirect_to login_path, alert: "Vennligst logg inn med PIN-kode"
    end
  end

  def current_agreement
    @current_agreement ||= RentalAgreement.last || RentalAgreement.new
  end
end
