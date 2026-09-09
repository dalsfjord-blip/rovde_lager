class VehicleLookupService
  include HTTParty
  base_uri "https://www.vegvesen.no/ws/no/vegvesen/kjoetoey/felles/datafordeler/v1"

  def initialize(api_key: nil)
    @api_key = api_key || Rails.application.credentials.vegvesenet_api_key || ENV["VEGVESENET_API_KEY"]
    @enabled = ENV.fetch("ENABLE_VEHICLE_LOOKUP", true)
  end

  def lookup(registration_number)
    return nil unless @enabled && @api_key.present?
    return nil if registration_number.blank?

    begin
      response = self.class.get(
        "/kjoetoey",
        headers: { "X-API-Key" => @api_key },
        query: { kjennemerke: registration_number.upcase }
      )

      if response.success? && response.parsed_response["kjoetoey"]
        parse_vehicle_data(response.parsed_response["kjoetoey"])
      else
        nil
      end
    rescue StandardError => e
      Rails.logger.warn "[VehicleLookupService] Feil ved oppslag: #{e.message}"
      nil
    end
  end

  private

  def parse_vehicle_data(vehicle_data)
    return nil unless vehicle_data.is_a?(Array) && vehicle_data.first

    data = vehicle_data.first
    length_mm = data.dig("godkjenning", "tekniskGodkjenning", "tekniskeData", "dimensjoner", "lengde")
    length_mm ||= data.dig("tekniskeData", "dimensjoner", "lengde")

    return nil unless length_mm

    {
      registration_number: data["kjennemerke"],
      length_mm: length_mm.to_f,
      length_m: (length_mm.to_f / 1000).round(2)
    }
  end
end
