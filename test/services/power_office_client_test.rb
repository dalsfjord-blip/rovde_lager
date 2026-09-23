require "test_helper"

class PowerOfficeClientTest < ActiveSupport::TestCase
  test "creates customer, sales order and invoice with cached token" do
    Rails.application.credentials.stub(:fetch, { subscription_key: "subscription", application_key: "application", client_key: "client" }) do
      connection = Faraday.new do |stub|
        stub.adapter :test do |tests|
          tests.post("https://goapi.poweroffice.net/Demo/OAuth/Token") { [ 200, {}, { access_token: "token", expires_in: 3600 }.to_json ] }
          tests.post("https://goapi.poweroffice.net/demo/v2/customers") { [ 200, {}, { Id: "customer-1" }.to_json ] }
          tests.post("https://goapi.poweroffice.net/demo/v2/salesorders") { [ 200, {}, { Id: "order-1" }.to_json ] }
          tests.post("https://goapi.poweroffice.net/demo/v2/salesorders/order-1/invoice") { [ 200, {}, { Id: "invoice-1", InvoiceNumber: "1001" }.to_json ] }
        end
      end

      Rails.cache.clear
      client = PowerOfficeClient.new(connection: connection)
      customer = client.create_customer(name: "Rovde AS", organization_number: "123456789", email: "faktura@example.com")
      order = client.create_sales_order(customer_id: customer.fetch("Id"), description: "Sesonglagring", unit_price: 800)
      invoice = client.invoice_sales_order(order.fetch("Id"))

      assert_equal "invoice-1", invoice.fetch("Id")
    end
  end
end
