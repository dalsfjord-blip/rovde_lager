require "test_helper"

class PowerOfficeInvoiceSyncJobTest < ActiveSupport::TestCase
  class FakeClient
    attr_reader :calls

    def initialize(customer_response: { "Id" => "customer-1", "Number" => 10024 }, invoice_response: { "Id" => "invoice-draft-1" }, send_response: { "Id" => "invoice-1", "InvoiceNo" => "42" })
      @customer_response = customer_response
      @invoice_response = invoice_response
      @send_response = send_response
      @calls = []
    end

    def create_customer(**args)
      @calls << [ :create_customer, args ]
      @customer_response
    end

    def create_invoice(**args)
      @calls << [ :create_invoice, args ]
      @invoice_response
    end

    def send_invoice(**args)
      @calls << [ :send_invoice, args ]
      @send_response
    end
  end

  def build_agreement
    RentalAgreement.create!(
      customer_name: "Ola Nordmann",
      customer_phone: "12345678",
      customer_email: "ola@example.com",
      contract_approved: true,
      total_meters: 1,
      total_price: 700,
      total_price_with_vat: 875,
      vat_amount: 175,
      business_customer: true,
      billing_company_name: "Rovde AS",
      billing_organization_number: "123456789",
      billing_email: "faktura@rovde.example",
      payment_method: "invoice",
      payment_status: "invoice_sent"
    )
  end

  test "creates customer and invoice draft, then waits for sending to be enabled" do
    ENV["POWEROFFICE_INVOICE_SEND_ENABLED"] = "false"
    agreement = build_agreement
    client = FakeClient.new

    PowerOfficeInvoiceSyncJob.perform_now(agreement.id, client: client)

    agreement.reload
    assert_equal "10024", agreement.power_office_customer_id
    assert_equal "invoice-draft-1", agreement.power_office_sales_order_id
    assert_nil agreement.power_office_invoice_id
    assert_equal "invoice_drafted", agreement.power_office_sync_status
    assert_equal %i[create_customer create_invoice], client.calls.map(&:first)
    assert_equal 3, agreement.power_office_sync_logs.count
  ensure
    ENV.delete("POWEROFFICE_INVOICE_SEND_ENABLED")
  end

  test "sends the invoice when sending is enabled" do
    ENV["POWEROFFICE_INVOICE_SEND_ENABLED"] = "true"
    agreement = build_agreement
    client = FakeClient.new

    PowerOfficeInvoiceSyncJob.perform_now(agreement.id, client: client)

    agreement.reload
    assert_equal "invoice-1", agreement.power_office_invoice_id
    assert_equal "42", agreement.power_office_invoice_number
    assert_equal "synced", agreement.power_office_sync_status
    assert agreement.power_office_synced_at.present?
  ensure
    ENV.delete("POWEROFFICE_INVOICE_SEND_ENABLED")
  end

  test "does nothing for private customers" do
    agreement = RentalAgreement.create!(
      customer_name: "Kari Nordmann",
      customer_phone: "12345678",
      customer_email: "kari@example.com",
      contract_approved: true,
      total_meters: 1,
      total_price: 700,
      payment_method: "manual",
      payment_status: "paid",
      paid_at: Time.current
    )
    client = FakeClient.new

    PowerOfficeInvoiceSyncJob.perform_now(agreement.id, client: client)

    assert_empty client.calls
    assert_nil agreement.reload.power_office_sync_status
  end

  test "marks the agreement as failed when PowerOffice rejects the invoice draft" do
    agreement = build_agreement
    client = FakeClient.new
    def client.create_invoice(**)
      raise PowerOfficeClient::RequestError.new(status: 404, retryable: false, detail: "Resource not found")
    end

    PowerOfficeInvoiceSyncJob.perform_now(agreement.id, client: client)

    agreement.reload
    assert_equal "failed", agreement.power_office_sync_status
    assert_match(/404/, agreement.power_office_sync_error)
  end

  test "is idempotent once an invoice already exists" do
    agreement = build_agreement
    agreement.update!(power_office_invoice_id: "already-synced")
    client = FakeClient.new

    PowerOfficeInvoiceSyncJob.perform_now(agreement.id, client: client)

    assert_empty client.calls
  end
end
