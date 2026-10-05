require "test_helper"

class PowerOfficeClientTest < ActiveSupport::TestCase
  Response = Struct.new(:status, :body) do
    def success?
      status.between?(200, 299)
    end
  end

  Request = Struct.new(:headers, :body, :params) do
    def initialize
      super({}, nil, {})
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

    def get(url)
      request = Request.new
      yield request
      @requests << [ :get, url, request ]
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

  test "creates a sales order complete with the given customer number and lines" do
    Rails.cache.delete("power_office/access_token")
    connection = Connection.new([
      Response.new(200, '{"access_token":"test-token","expires_in":1200}'),
      Response.new(201, '{"Id":"sales-order-1"}')
    ])
    client = build_client(connection)

    response = client.create_sales_order(
      customer_number: 10024,
      reference: "ROLAG-RE-10001",
      lines: [ { ProductId: 555, Description: "Sesonglagring ROLAG-RE-10001", Quantity: 1, ProductUnitPrice: 700.0 } ]
    )

    assert_equal "sales-order-1", response["Id"]
    body = JSON.parse(connection.requests.last.last.body)
    assert_equal 10024, body["CustomerNo"]
    assert_equal "ROLAG-RE-10001", body["ExternalImportReference"]
    assert_equal 555, body["SalesOrderLines"].first["ProductId"]
  ensure
    Rails.cache.delete("power_office/access_token")
  end

  test "finds an existing product by code without creating a new one" do
    Rails.cache.delete("power_office/access_token")
    connection = Connection.new([
      Response.new(200, '{"access_token":"test-token","expires_in":1200}'),
      Response.new(200, '[{"Id":555,"Code":"SESONGLAGRING"}]')
    ])
    client = build_client(connection)

    product_id = client.ensure_service_product!(code: "SESONGLAGRING", name: "Sesonglagring")

    assert_equal 555, product_id
    assert_equal 2, connection.requests.size
  ensure
    Rails.cache.delete("power_office/access_token")
  end

  test "creates a product linked to a sales account with the right vat code when missing" do
    Rails.cache.delete("power_office/access_token")
    connection = Connection.new([
      Response.new(200, '{"access_token":"test-token","expires_in":1200}'),
      Response.new(200, "[]"),
      Response.new(200, '{"access_token":"test-token","expires_in":1200}'),
      Response.new(200, '[{"Id":3000,"AccountNo":3000,"VatCode":"3"},{"Id":3100,"AccountNo":3100,"VatCode":"1"}]'),
      Response.new(200, '{"access_token":"test-token","expires_in":1200}'),
      Response.new(201, '{"Id":777,"Code":"SESONGLAGRING"}')
    ])
    client = build_client(connection)

    product_id = client.ensure_service_product!(code: "SESONGLAGRING", name: "Sesonglagring")

    assert_equal 777, product_id
    create_request = connection.requests.last.last
    body = JSON.parse(create_request.body)
    assert_equal 3000, body["StandardSalesAccountId"]
  ensure
    Rails.cache.delete("power_office/access_token")
  end

  test "raises a configuration error when no sales account matches the vat code" do
    Rails.cache.delete("power_office/access_token")
    connection = Connection.new([
      Response.new(200, '{"access_token":"test-token","expires_in":1200}'),
      Response.new(200, "[]"),
      Response.new(200, '{"access_token":"test-token","expires_in":1200}'),
      Response.new(200, "[]")
    ])
    client = build_client(connection)

    assert_raises(PowerOfficeClient::ConfigurationError) do
      client.ensure_service_product!(code: "SESONGLAGRING", name: "Sesonglagring")
    end
  ensure
    Rails.cache.delete("power_office/access_token")
  end

  test "creates a send request for a sales order" do
    Rails.cache.delete("power_office/access_token")
    connection = Connection.new([
      Response.new(200, '{"access_token":"test-token","expires_in":1200}'),
      Response.new(202, '{"Id":"sales-order-1"}')
    ])
    client = build_client(connection)

    response = client.create_and_send_invoice(sales_order_id: "sales-order-1", delivery_type: "Auto", email: "faktura@rovde.example")

    assert_equal "sales-order-1", response["Id"]
    body = JSON.parse(connection.requests.last.last.body)
    assert_equal "Auto", body["DeliveryType"]
    assert_equal "faktura@rovde.example", body["EmailAddress"]
  ensure
    Rails.cache.delete("power_office/access_token")
  end

  test "polls the sent state of a sales order" do
    Rails.cache.delete("power_office/access_token")
    connection = Connection.new([
      Response.new(200, '{"access_token":"test-token","expires_in":1200}'),
      Response.new(200, '[{"Id":"sales-order-1","InvoiceNo":42,"SentDateTimeOffset":"2024-09-03T11:35:00Z"}]')
    ])
    client = build_client(connection)

    response = client.sent_state(sales_order_id: "sales-order-1")

    assert_equal 42, response.first["InvoiceNo"]
    assert_equal({ id: "sales-order-1" }, connection.requests.last.last.params)
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

    error = assert_raises(PowerOfficeClient::RequestError) { client.create_and_send_invoice(sales_order_id: "sales-order-1") }
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

    error = assert_raises(PowerOfficeClient::RequestError) { client.create_and_send_invoice(sales_order_id: "sales-order-1") }
    assert_not error.retryable
  ensure
    Rails.cache.delete("power_office/access_token")
  end
end
