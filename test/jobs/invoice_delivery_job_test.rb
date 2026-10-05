require "test_helper"

class InvoiceDeliveryJobTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  test "triggers PowerOffice sync once for a paid business receipt and sends no email" do
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
      payment_method: "vipps",
      payment_status: "paid",
      paid_at: Time.current
    )

    with_power_office_configured do
      assert_enqueued_jobs 1, only: PowerOfficeInvoiceSyncJob do
        InvoiceDeliveryJob.perform_now(agreement.id, receipt: true)
        InvoiceDeliveryJob.perform_now(agreement.id, receipt: true)
      end
    end

    assert agreement.reload.receipt_sent_at.present?
    assert_match(/\A\d+-ROLAG\z/, agreement.invoice_number)
    assert_empty ActionMailer::Base.deliveries
  end

  test "triggers PowerOffice sync once for afterpayment invoice and sends no email" do
    agreement = create_invoice_agreement

    with_power_office_configured do
      assert_enqueued_jobs 1, only: PowerOfficeInvoiceSyncJob do
        InvoiceDeliveryJob.perform_now(agreement.id)
        InvoiceDeliveryJob.perform_now(agreement.id)
      end
    end

    agreement.reload
    assert_equal "invoice_sent", agreement.payment_status
    assert agreement.invoice_sent_at.present?
    assert_match(/\A\d+-ROLAG\z/, agreement.invoice_number)
    assert_empty ActionMailer::Base.deliveries
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

    with_power_office_configured do
      assert_no_enqueued_jobs do
        InvoiceDeliveryJob.perform_now(agreement.id)
      end
    end

    assert_nil agreement.reload.invoice_sent_at
  end

  private

  def with_power_office_configured
    PowerOfficeClient.define_method(:configured?) { true }
    yield
  ensure
    PowerOfficeClient.define_method(:configured?) { [ @application_key, @client_key, @subscription_key ].all?(&:present?) }
  end

  def create_invoice_agreement
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
      payment_status: "invoice_pending"
    )
  end
end
