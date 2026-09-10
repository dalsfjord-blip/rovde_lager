class VehicleLookupService
  include HTTParty
  base_uri "https://akfell-datautlevering.atlas.vegvesen.no/enkeltoppslag"

  def initialize(api_key: nil)
    @api_key = api_key || Rails.application.credentials.vegvesenet_api || ENV["VEGVESENET_API_KEY"]
    @enabled = ENV.fetch("ENABLE_VEHICLE_LOOKUP", "true").to_s == "true"
  end

  def lookup(registration_number)
    return nil unless @enabled && @api_key.present?
    return nil if registration_number.blank?

    reg_nr = registration_number.to_s.strip.gsub(/\s+/, "").upcase

    begin
      response = self.class.get(
        "/kjoretoydata",
        headers: {
          "SVV-Authorization" => "Apikey #{@api_key}",
          "Accept" => "application/json"
        },
        query: { kjennemerke: reg_nr }
      )

      if response.success? && response.parsed_response.present?
        parse_vehicle_data(response.parsed_response)
      else
        Rails.logger.warn "[VehicleLookupService] API svarte med status #{response.code} for #{reg_nr}"
        nil
      end
    rescue StandardError => e
      Rails.logger.error "[VehicleLookupService] Feil ved oppslag: #{e.message}"
      nil
    end
  end

  private

  def parse_vehicle_data(parsed_response)
    kjoretoy_liste = parsed_response.is_a?(Array) ? parsed_response : parsed_response["kjoretoydataListe"]
    data = kjoretoy_liste&.first
    return nil unless data

    tekniske_data = data.dig("godkjenning", "tekniskGodkjenning", "tekniskeData")
    length_mm = tekniske_data&.dig("dimensjoner", "lengde")
    merke = data.dig("godkjenning", "tekniskGodkjenning", "kjøretøymerke") ||
            tekniske_data&.dig("generelt", "merke", 0, "merke")

    return nil unless length_mm

    length_m = (length_mm.to_f / 1000.0).round(2)

    {
      registration_number: data.dig("kjoretoyid", "kjennemerke") || data["kjennemerke"],
      length_mm: length_mm.to_f,
      length_m: length_m,
      make: merke
    }
  end
end
