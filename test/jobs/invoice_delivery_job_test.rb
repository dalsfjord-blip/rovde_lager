require "test_helper"

class InvoiceDeliveryJobTest < ActionMailer::TestCase
  test "sends a paid business receipt only once" do
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

    assert_emails 1 do
      InvoiceDeliveryJob.perform_now(agreement.id, receipt: true)
      InvoiceDeliveryJob.perform_now(agreement.id, receipt: true)
    end

    assert agreement.reload.receipt_sent_at.present?
  end
end
