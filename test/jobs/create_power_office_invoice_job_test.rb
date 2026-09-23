require "test_helper"

class CreatePowerOfficeInvoiceJobTest < ActiveJob::TestCase
  test "keeps the customer ID when sales order creation fails" do
    agreement = RentalAgreement.create!(
      customer_name: "Ola Nordmann",
      customer_phone: "12345678",
      customer_email: "ola@example.com",
      contract_approved: true,
      payment_method: "invoice",
      billing_company_name: "Rovde AS",
      billing_organization_number: "123456789",
      billing_email: "faktura@rovde.example",
      total_meters: 4.5,
      total_price: 3150,
      total_price_with_vat: 3150,
      vat_amount: 630,
      invoice_sync_status: "queued"
    )
    client = Object.new
    client.define_singleton_method(:create_customer) { |**| { "Id" => "customer-1" } }
    client.define_singleton_method(:create_sales_order) do |**|
      raise PowerOfficeClient::RequestError.new(status: 400, retryable: false, detail: "MVA-kode mangler")
    end

    CreatePowerOfficeInvoiceJob.perform_now(agreement.id, client: client)

    agreement.reload
    assert_equal "customer-1", agreement.power_office_customer_id
    assert_equal "failed", agreement.invoice_sync_status
    assert_equal "PowerOffice 400: MVA-kode mangler", agreement.invoice_sync_error
  end
end
