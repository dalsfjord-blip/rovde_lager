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
      total_price: 2100,
      pickup_date: Date.new(2026, 4, 1)
    )

    email = RentalAgreementMailer.confirmation_email(agreement)

    assert_emails 1 do
      email.deliver_now
    end

    assert_equal [ agreement.customer_email ], email.to
    assert_match(/\AROLAG-RE-\d+\z/, agreement.reference_number)
    assert_match agreement.reference_number, email.subject
    assert_match agreement.customer_name, email.body.encoded
    assert_match "1. april 2026", email.body.encoded
    assert_match "Leietaker er ansvarlig for at enheten er forsikret", email.body.encoded
    assert_no_match(/Status:/, email.body.encoded)
  end
end
