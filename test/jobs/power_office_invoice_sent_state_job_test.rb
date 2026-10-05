require "test_helper"

class PowerOfficeInvoiceSentStateJobTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  class FakeClient
    attr_reader :calls

    def initialize(responses)
      @responses = responses
      @calls = []
    end

    def sent_state(**args)
      @calls << [ :sent_state, args ]
      @responses.shift
    end
  end

  def build_agreement
    agreement = RentalAgreement.create!(
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
    agreement.update!(power_office_customer_id: "10024", power_office_sales_order_id: "sales-order-1", power_office_sync_status: "sending")
    agreement
  end

  test "marks the agreement as synced when the invoice is sent" do
    agreement = build_agreement
    client = FakeClient.new([
      [ { "Id" => "sales-order-1", "InvoiceNo" => 42, "SentDateTimeOffset" => "2024-09-03T11:35:00Z" } ]
    ])

    PowerOfficeInvoiceSentStateJob.perform_now(agreement.id, client: client)

    agreement.reload
    assert_equal "synced", agreement.power_office_sync_status
    assert_equal "sales-order-1", agreement.power_office_invoice_id
    assert_equal "42", agreement.power_office_invoice_number
    assert agreement.power_office_synced_at.present?
  end

  test "marks the agreement as failed when PowerOffice reports a delivery error" do
    agreement = build_agreement
    client = FakeClient.new([
      [ { "Id" => "sales-order-1", "LastErrorMessage" => "Kunden støtter ikke lenger mottak av EHF-faktura" } ]
    ])

    PowerOfficeInvoiceSentStateJob.perform_now(agreement.id, client: client)

    agreement.reload
    assert_equal "failed", agreement.power_office_sync_status
    assert_match(/EHF/, agreement.power_office_sync_error)
  end

  test "reschedules itself while the invoice is still being processed" do
    agreement = build_agreement
    client = FakeClient.new([
      [ { "Id" => "sales-order-1", "IsInvoiceBeingProcessed" => true } ]
    ])

    assert_enqueued_with(job: PowerOfficeInvoiceSentStateJob, args: [ agreement.id, { attempt: 2 } ]) do
      PowerOfficeInvoiceSentStateJob.perform_now(agreement.id, client: client)
    end

    agreement.reload
    assert_equal "sending", agreement.power_office_sync_status
  end

  test "marks the agreement as failed after exceeding max attempts" do
    agreement = build_agreement
    client = FakeClient.new([
      [ { "Id" => "sales-order-1", "IsInvoiceBeingProcessed" => true } ]
    ])

    PowerOfficeInvoiceSentStateJob.perform_now(agreement.id, attempt: PowerOfficeInvoiceSentStateJob::MAX_ATTEMPTS, client: client)

    agreement.reload
    assert_equal "failed", agreement.power_office_sync_status
    assert_match(/Tidsavbrudd/, agreement.power_office_sync_error)
  end

  test "is idempotent once an invoice already exists" do
    agreement = build_agreement
    agreement.update!(power_office_invoice_id: "already-synced")
    client = FakeClient.new([])

    PowerOfficeInvoiceSentStateJob.perform_now(agreement.id, client: client)

    assert_empty client.calls
  end
end
