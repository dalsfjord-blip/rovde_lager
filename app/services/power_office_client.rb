class PowerOfficeClient
  class ConfigurationError < StandardError; end

  def initialize
    @subscription_key = credentials[:subscription_key]
    @application_key = credentials[:application_key]
    @client_key = credentials[:client_key]
  end

  def configured?
    [@subscription_key, @application_key, @client_key].all?(&:present?)
  end

  def ensure_configured!
    return if configured?

    raise ConfigurationError, "PowerOffice credentials mangler"
  end

  private

  def credentials
    Rails.application.credentials.fetch(:power_office, {})
  end
end
