require "test_helper"

class BookingFlowTest < ActionDispatch::IntegrationTest
  test "requires login before accessing registration" do
    get storage_items_path

    assert_redirected_to login_path
  end

  test "creates a session-specific agreement and completes invoice flow" do
    sign_in

    post storage_items_path, params: {
      rental_agreement: {
        storage_items_attributes: {
          "0" => { registration_number: "AB12345", description: "", meters: "4.5" }
        }
      }
    }

    agreement = RentalAgreement.last
    assert_redirected_to contract_path
    assert_equal 4.5, agreement.total_meters.to_f
    assert_equal 3150, agreement.total_price.to_f

    get contract_path

    assert_response :success
    assert_select "button", "Åpne kamera"

    patch customer_info_path, params: {
      rental_agreement: {
        customer_name: "Ola Nordmann",
        customer_phone: "12345678",
        customer_email: "ola@example.com",
        pickup_date: "2026-04-01",
        contract_approved: "1"
      }
    }

    assert_redirected_to payment_path

    post payment_path, params: { payment_method: "invoice" }

    assert_redirected_to receipt_path
    assert_equal "invoice", agreement.reload.payment_method
    assert_equal "pending", agreement.payment_status

    get receipt_path

    assert_response :success
    assert_includes response.body, agreement.reference_number
    assert_includes response.body, "Ola Nordmann"
  end

  test "attaches photos submitted with customer information" do
    sign_in

    post storage_items_path, params: {
      rental_agreement: {
        storage_items_attributes: {
          "0" => { registration_number: "AB12345", description: "", meters: "4.5" }
        }
      }
    }

    photo = Tempfile.new(["lagringsobjekt", ".jpg"])
    photo.write("image data")
    photo.close

    patch customer_info_path, params: {
      rental_agreement: {
        customer_name: "Ola Nordmann",
        customer_phone: "12345678",
        customer_email: "ola@example.com",
        pickup_date: "2026-04-01",
        contract_approved: "1",
        photos: [Rack::Test::UploadedFile.new(photo.path, "image/jpeg")]
      }
    }

    assert_redirected_to payment_path
    assert_equal 1, RentalAgreement.last.reload.photos.count
  ensure
    photo.unlink
  end

  test "does not expose another session's agreement" do
    agreement = RentalAgreement.create!(
      customer_name: "Eksisterende kunde",
      customer_phone: "12345678",
      customer_email: "eksisterende@example.com",
      total_meters: 3,
      total_price: 2100
    )

    sign_in
    get receipt_path

    assert_redirected_to storage_items_path
    assert_not_equal agreement.id, session[:rental_agreement_id]
  end

  private

  def sign_in
    post sessions_path, params: { pin: "1234" }
    assert_redirected_to storage_items_path
  end
end
