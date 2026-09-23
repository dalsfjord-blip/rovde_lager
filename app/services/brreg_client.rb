class BrregClient
  BASE_URL = "https://data.brreg.no/enhetsregisteret/api/enheter"
  CACHE_TTL = 1.hour
  TIMEOUT = 3

  def initialize(connection: nil)
    @connection = connection
  end

  def search(name)
    query = name.to_s.strip
    return [] if query.length < 2

    Rails.cache.fetch("brreg/search/#{query.downcase}", expires_in: CACHE_TTL) do
      response = connection.get(BASE_URL, navn: query)
      return [] unless response.success?

      Array(JSON.parse(response.body).dig("_embedded", "enheter")).map { |entity| present(entity) }
    end
  rescue Faraday::Error, JSON::ParserError
    []
  end

  def lookup(organization_number)
    normalized_number = organization_number.to_s.gsub(/\D/, "")
    return nil unless normalized_number.match?(/\A\d{9}\z/)

    Rails.cache.fetch("brreg/entity/#{normalized_number}", expires_in: CACHE_TTL) do
      response = connection.get("#{BASE_URL}/#{normalized_number}")
      return nil unless response.success?

      present(JSON.parse(response.body))
    end
  rescue Faraday::Error, JSON::ParserError
    nil
  end

  private

  def connection
    @connection ||= Faraday.new(request: { open_timeout: TIMEOUT, timeout: TIMEOUT })
  end

  def present(entity)
    {
      name: entity["navn"],
      organization_number: entity["organisasjonsnummer"].to_s,
      address: Array(entity.dig("forretningsadresse", "adresse")).join(", "),
      postal_code: entity.dig("forretningsadresse", "postnummer"),
      city: entity.dig("forretningsadresse", "poststed")
    }
  end
end
