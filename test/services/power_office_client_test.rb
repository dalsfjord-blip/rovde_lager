require "test_helper"

class PowerOfficeClientTest < ActiveSupport::TestCase
  Response = Struct.new(:status, :body) do
    def success?
      status.between?(200, 299)
    end
  end

  Request = Struct.new(:headers, :body) do
    def initialize
      super({})
    end
  end

  class Connection
    attr_reader :requests

    def initialize(responses)
      @responses = responses
      @requests = []
    end

    def post(url)
      request = Request.new
      yield request
      @requests << [ :post, url, request ]
      @responses.shift
    end
  end

  def build_client(connection)
    client = PowerOfficeClient.new(connection: connection)
    client.instance_variable_set(:@application_key, "app-key")
    client.instance_variable_set(:@client_key, "client-key")
    client.instance_variable_set(:@subscription_key, "subscription-key")
    client.instance_variable_set(:@token_url, "https://goapi.poweroffice.net/Demo/OAuth/Token")
    client.instance_variable_set(:@base_url, "https://goapi.poweroffice.net/Demo/v2")
    client
  end

  test "creates a customer with organization details" do
    Rails.cache.delete("power_office/access_token")
    connection = Connection.new([
      Response.new(200, '{"access_token":"test-token","expires_in":1200}'),
      Response.new(200, '{"Id":12345,"Number":10024,"Name":"Rovde AS"}')
    ])
    client = build_client(connection)

    response = client.create_customer(name: "Rovde AS", organization_number: "123456789", email: "faktura@rovde.example")

    assert_equal 10024, response["Number"]
    assert_equal "Bearer test-token", connection.requests.last.last.headers["Authorization"]
    body = JSON.parse(connection.requests.last.last.body)
    assert_equal "Rovde AS", body["Name"]
    assert_equal "123456789", body["OrganizationNumber"]
  ensure
    Rails.cache.delete("power_office/access_token")
  end

  test "creates an invoice draft with the given customer number and vat code" do
    Rails.cache.delete("power_office/access_token")
    connection = Connection.new([
      Response.new(200, '{"access_token":"test-token","expires_in":1200}'),
      Response.new(200, '{"Id":"invoice-1"}')
    ])
    client = build_client(connection)

    response = client.create_invoice(customer_number: 10024, description: "Sesonglagring ROLAG-RE-10001", unit_price: 700.0, reference: "ROLAG-RE-10001")

    assert_equal "invoice-1", response["Id"]
    body = JSON.parse(connection.requests.last.last.body)
    assert_equal 10024, body["CustomerCode"]
    assert_equal "3", body["OutgoingInvoiceLines"].first["VatCode"]
    assert_equal "ROLAG-RE-10001", body["CustomerReference"]
  ensure
    Rails.cache.delete("power_office/access_token")
  end

  test "raises a retryable error for server failures" do
    Rails.cache.delete("power_office/access_token")
    connection = Connection.new([
      Response.new(200, '{"access_token":"test-token","expires_in":1200}'),
      Response.new(503, "service unavailable")
    ])
    client = build_client(connection)

    error = assert_raises(PowerOfficeClient::RequestError) { client.send_invoice(invoice_id: "invoice-1", email: "faktura@rovde.example") }
    assert error.retryable
  ensure
    Rails.cache.delete("power_office/access_token")
  end

  test "raises a non-retryable error when the resource is not found" do
    Rails.cache.delete("power_office/access_token")
    connection = Connection.new([
      Response.new(200, '{"access_token":"test-token","expires_in":1200}'),
      Response.new(404, '{ "statusCode": 404, "message": "Resource not found" }')
    ])
    client = build_client(connection)

    error = assert_raises(PowerOfficeClient::RequestError) { client.send_invoice(invoice_id: "invoice-1", email: "faktura@rovde.example") }
    assert_not error.retryable
  ensure
    Rails.cache.delete("power_office/access_token")
  end
end
