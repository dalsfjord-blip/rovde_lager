require "test_helper"

class BookingFlowTest < ActionDispatch::IntegrationTest
  test "requires login before accessing registration" do
    get storage_items_path

    assert_redirected_to login_path
  end

  test "completes registration with an invoice from one form" do
    sign_in

    get storage_items_path

    assert_response :success
    assert_select "h1", "Registrering"
    assert_select "button", "Åpne kamera"
    assert_select "#contract_text[style*='overflow-y: auto']"
    assert_select "input[name='rental_agreement[contract_approved]'][data-items-target='contractApproval'][disabled]"
    assert_select "label", "Send avtaleteksten på e-post"
    assert_select "input[name='rental_agreement[payment_method]']", 2

    post storage_items_path, params: registration_params

    agreement = RentalAgreement.last
    assert_redirected_to receipt_path
    assert_equal 4.5, agreement.total_meters.to_f
    assert_equal 3150, agreement.total_price.to_f
    assert_equal "Ola Nordmann", agreement.customer_name
    assert agreement.contract_approved
    assert agreement.send_email_copy
    assert_equal "invoice", agreement.payment_method
    assert_equal "pending", agreement.payment_status

    get receipt_path

    assert_response :success
    assert_includes response.body, agreement.reference_number
    assert_includes response.body, "Ola Nordmann"
  end

  test "attaches camera photos submitted with the registration" do
    sign_in
    photo = Tempfile.new(["lagringsobjekt", ".jpg"])
    photo.write("image data")
    photo.close

    post storage_items_path, params: registration_params(photos: [Rack::Test::UploadedFile.new(photo.path, "image/jpeg")])

    assert_redirected_to receipt_path
    assert_equal 1, RentalAgreement.last.reload.photos.count
  ensure
    photo.unlink
  end

  test "requires contract approval before completing registration" do
    sign_in

    post storage_items_path, params: registration_params.tap { |params| params[:rental_agreement].delete(:contract_approved) }

    assert_response :unprocessable_entity
    assert_includes response.body, "må godkjennes"
  end

  test "does not expose another session's agreement" do
    agreement = RentalAgreement.create!(
      customer_name: "Eksisterende kunde",
      customer_phone: "12345678",
      customer_email: "eksisterende@example.com",
      contract_approved: true,
      total_meters: 3,
      total_price: 2100
    )

    sign_in
    get receipt_path

    assert_redirected_to storage_items_path
    assert_not_equal agreement.id, session[:rental_agreement_id]
  end

  private

  def registration_params(photos: [])
    {
      rental_agreement: {
        customer_name: "Ola Nordmann",
        customer_phone: "12345678",
        customer_email: "ola@example.com",
        pickup_date: "2026-04-01",
        payment_method: "invoice",
        contract_approved: "1",
        send_email_copy: "1",
        photos: photos,
        storage_items_attributes: {
          "0" => { registration_number: "AB12345", description: "", meters: "4.5" }
        }
      }
    }
  end

  def sign_in
    post sessions_path, params: { pin: "1234" }
    assert_redirected_to storage_items_path
  end
end
