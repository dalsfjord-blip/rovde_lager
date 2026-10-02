require "test_helper"

class HarborRentalInvoiceDeliveryJobTest < ActionMailer::TestCase
  test "sends a harbor rental invoice only once" do
    harbor_rental = create_harbor_rental

    assert_emails 1 do
      HarborRentalInvoiceDeliveryJob.perform_now(harbor_rental.id)
      HarborRentalInvoiceDeliveryJob.perform_now(harbor_rental.id)
    end

    harbor_rental.reload
    assert_equal "invoice_sent", harbor_rental.payment_status
    assert harbor_rental.invoice_sent_at.present?
    assert_match(/\A\d+-ROHAMN\z/, harbor_rental.invoice_number)
    assert_includes ActionMailer::Base.deliveries.last.text_part.body.decoded, "Kommentar: Kontakt oss før ankomst."
    assert_equal 3000, harbor_rental.total_price
    assert_equal 750, harbor_rental.vat_amount
    assert_equal 3750, harbor_rental.total_price_with_vat
    assert_equal "Kontakt oss før ankomst.", harbor_rental.comments
    assert_equal [ "rovdeindustri@faktura.poweroffice.net" ], ActionMailer::Base.deliveries.last.cc
  end

  private

  def create_harbor_rental
    user = User.create!(name: "Ola Nordmann", email: "ola@example.com", phone_number: "12345678")
    HarborRental.create!(
      user: user,
      days: 2,
      billing_company_name: "Rovde AS",
      billing_organization_number: "123456789",
      billing_email: "faktura@rovde.example",
      comments: "Kontakt oss før ankomst.",
      payment_status: "invoice_pending"
    )
  end
end
