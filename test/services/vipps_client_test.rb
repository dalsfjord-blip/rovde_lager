require "test_helper"

class VippsClientTest < ActiveSupport::TestCase
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

  test "accepts an empty successful capture response" do
    Rails.cache.delete("vipps/access_token")
    connection = Connection.new([
      Response.new(200, '{"access_token":"test-token"}'),
      Response.new(204, "")
    ])
    client = VippsClient.new(connection: connection)
    client.instance_variable_set(:@client_id, "client-id")
    client.instance_variable_set(:@client_secret, "client-secret")
    client.instance_variable_set(:@subscription_key, "subscription-key")
    client.instance_variable_set(:@merchant_serial_number, "540057")
    client.instance_variable_set(:@base_url, "https://apitest.vipps.no")

    assert_equal({}, client.capture_payment("LAG-1", 10_000))
    assert_equal "capture-LAG-1", connection.requests.last.last.headers["Idempotency-Key"]
    assert_equal({ "modificationAmount" => { "currency" => "NOK", "value" => 10_000 } }, JSON.parse(connection.requests.last.last.body))
  ensure
    Rails.cache.delete("vipps/access_token")
  end
end
