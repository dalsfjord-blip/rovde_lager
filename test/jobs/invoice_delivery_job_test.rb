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
    assert_match(/\A\d+-ROLAG\z/, agreement.invoice_number)
    assert_equal [ "rovdeindustri@faktura.poweroffice.net" ], ActionMailer::Base.deliveries.last.cc
  end

  test "sends an invoice for afterpayment and marks it sent" do
    agreement = create_invoice_agreement

    assert_emails 1 do
      InvoiceDeliveryJob.perform_now(agreement.id)
      InvoiceDeliveryJob.perform_now(agreement.id)
    end

    agreement.reload
    assert_equal "invoice_sent", agreement.payment_status
    assert agreement.invoice_sent_at.present?
    assert_match(/\A\d+-ROLAG\z/, agreement.invoice_number)
    assert_includes ActionMailer::Base.deliveries.last.body.encoded, "Kontonummer for innbetaling: 3626 58 20780"
  end

  test "sends a private invoice without VAT and with the invoice fee" do
    agreement = RentalAgreement.create!(
      customer_name: "Ola Nordmann",
      customer_phone: "12345678",
      customer_email: "ola@example.com",
      contract_approved: true,
      total_meters: 1,
      total_price: 700,
      total_price_with_vat: 800,
      private_invoice_fee: 100,
      vat_amount: 0,
      business_customer: false,
      payment_method: "private_invoice",
      payment_status: "invoice_pending"
    )

    assert_emails 1 do
      InvoiceDeliveryJob.perform_now(agreement.id)
    end

    agreement.reload
    email = ActionMailer::Base.deliveries.last
    assert_equal "invoice_sent", agreement.payment_status
    assert_equal [ "ola@example.com" ], email.to
    assert_equal "faktura@rovdeindustripark.app", email.from.first
    assert_equal [ "rovdeindustri@faktura.poweroffice.net" ], email.cc
    assert_equal "faktura-#{agreement.invoice_number}.pdf", email.attachments.first.filename
    assert_equal 100, agreement.private_invoice_fee.to_f
    assert_equal 800, agreement.total_price_with_vat.to_f
  end

  private

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
