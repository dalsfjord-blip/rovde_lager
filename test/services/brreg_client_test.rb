require "test_helper"

class BrregClientTest < ActiveSupport::TestCase
  test "returns search results and normalizes company data" do
    connection = Faraday.new do |stub|
      stub.adapter :test do |tests|
        tests.get("https://data.brreg.no/enhetsregisteret/api/enheter?navn=Rovde") do
          [ 200, {}, { _embedded: { enheter: [ { navn: "Rovde AS", organisasjonsnummer: "123456789", forretningsadresse: { adresse: [ "Havnevegen 1" ], postnummer: "6141", poststed: "Rovde" } } ] } }.to_json ]
        end
      end
    end

    Rails.cache.clear
    result = BrregClient.new(connection: connection).search("Rovde")

    assert_equal [ { name: "Rovde AS", organization_number: "123456789", address: "Havnevegen 1", postal_code: "6141", city: "Rovde" } ], result
  end

  test "allows manual entry when lookup is unavailable" do
    connection = Faraday.new do |stub|
      stub.adapter :test do |tests|
        tests.get("https://data.brreg.no/enhetsregisteret/api/enheter/123456789") { [ 503, {}, "" ] }
      end
    end

    Rails.cache.clear
    assert_nil BrregClient.new(connection: connection).lookup("123 456 789")
  end
end
