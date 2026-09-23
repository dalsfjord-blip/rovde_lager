require "test_helper"

class RentalAgreementMailerTest < ActionMailer::TestCase
  test "confirmation email" do
    agreement = rental_agreements(:one)
    email = RentalAgreementMailer.confirmation_email(agreement)

    assert_emails 1 do
      email.deliver_now
    end

    assert_equal [ agreement.customer_email ], email.to
    assert_match agreement.reference_number, email.subject
    assert_match agreement.customer_name, email.body.encoded
  end
end
