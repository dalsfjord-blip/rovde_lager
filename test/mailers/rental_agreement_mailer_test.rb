require "test_helper"

class RentalAgreementMailerTest < ActionMailer::TestCase
  test "confirmation email" do
    agreement = RentalAgreement.create!(
      customer_name: "Ola Nordmann",
      customer_phone: "12345678",
      customer_email: "ola@example.com",
      contract_approved: true,
      payment_method: "vipps",
      total_meters: 3,
      total_price: 2100
    )

    email = RentalAgreementMailer.confirmation_email(agreement)

    assert_emails 1 do
      email.deliver_now
    end

    assert_equal [ agreement.customer_email ], email.to
    assert_match agreement.reference_number, email.subject
    assert_match agreement.customer_name, email.body.encoded
  end
end
