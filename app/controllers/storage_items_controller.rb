class StorageItemsController < ApplicationController
  before_action :load_agreement, only: [:index, :create, :remove_item]

  def index
    start_agreement if params[:new].present?
    @agreement = current_agreement || RentalAgreement.new
    @vipps_payment_url = session[:vipps_payment_url]
    @vipps_reference = session[:vipps_reference]
    @agreement.storage_items.build if @agreement.storage_items.empty?
    @storage_items = @agreement.storage_items
    set_pickup_dates
  end

  def create
    @agreement.assign_attributes(agreement_params)
    calculate_totals
    set_payment_status

    if @agreement.save
      send_confirmation_email
      vipps_payment_url = start_payment_processing
      start_agreement
      if vipps_payment_url
        session[:vipps_payment_url] = vipps_payment_url
        session[:vipps_reference] = @agreement.vipps_reference
      end
      notice = @agreement.invoice? || @agreement.payment_method == "manual" ? payment_notice : (vipps_payment_url ? payment_notice : "Vipps-kravet kunne ikke opprettes.")
      redirect_to storage_items_path(new: true), notice: notice
    else
      @storage_items = @agreement.storage_items
      set_pickup_dates
      render :index, status: :unprocessable_entity
    end
  end

  def remove_item
    item = @agreement.storage_items.find(params[:id])
    item.destroy!
    calculate_totals
    @agreement.save!(validate: false)
    redirect_to storage_items_path, notice: "Lagringsobjekt fjernet."
  end

  private

  def load_agreement
    @agreement = current_agreement || RentalAgreement.new
  end

  def agreement_params
    params.require(:rental_agreement).permit(
      :customer_name,
      :customer_phone,
      :customer_email,
      :pickup_date,
      :special_needs,
      :special_needs_notes,
      :send_email_copy,
      :contract_approved,
      :payment_method,
      :business_customer,
      :billing_company_name,
      :billing_organization_number,
      :billing_email,
      photos: [],
      storage_items_attributes: [:id, :registration_number, :description, :meters, :_destroy]
    )
  end

  def calculate_totals
    total_meters = @agreement.storage_items.reject(&:marked_for_destruction?).sum { |item| item.meters || 0 }
    total_price = total_meters * 700
    @agreement.total_meters = total_meters
    @agreement.total_price = total_price
    if @agreement.business_customer?
      @agreement.vat_amount = (total_price * RentalAgreement::VAT_RATE).round(2)
      @agreement.total_price_with_vat = total_price + @agreement.vat_amount
    else
      @agreement.vat_amount = 0
      @agreement.total_price_with_vat = total_price
    end
  end

  def set_payment_status
    @agreement.payment_status = if @agreement.invoice?
      "invoice_pending"
    elsif @agreement.payment_method == "manual"
      "paid"
    else
      "payment_pending"
    end
    @agreement.paid_at = Time.current if @agreement.payment_method == "manual"
  end

  def payment_notice
    return "Fakturaen sendes." if @agreement.invoice?
    return "Betalingen er registrert." if @agreement.payment_method == "manual"

    "Skann QR-koden for å betale med Vipps."
  end

  def start_payment_processing
    if @agreement.invoice?
      InvoiceDeliveryJob.perform_later(@agreement.id)
      nil
    elsif @agreement.payment_method == "vipps"
      create_vipps_payment
    end
  end

  def create_vipps_payment
    return create_demo_vipps_payment unless VippsClient.new.configured?

    reference = "LAG-#{@agreement.id}-#{SecureRandom.uuid.delete('-')[0, 20].upcase}"
    @agreement.update!(vipps_reference: reference)
    payment_url = VippsClient.new.create_payment(
      reference: reference,
      amount_in_oere: (@agreement.total_price_with_vat * 100).round,
      return_url: "https://vipps.no",
      phone_number: @agreement.customer_phone,
      description: "Sesonglagring #{@agreement.reference_number}"
    )
    @agreement.update!(vipps_payment_url: payment_url, vipps_payment_created_at: Time.current)
    payment_url
  rescue VippsClient::RequestError, VippsClient::ConfigurationError
    @agreement.update!(payment_status: "failed")
    nil
  end

  def create_demo_vipps_payment
    reference = "DEMO-#{@agreement.id}-#{SecureRandom.uuid.delete('-')[0, 12].upcase}"
    payment_url = "https://example.test/vipps-demo/#{reference}"
    @agreement.update!(vipps_reference: reference, vipps_payment_url: payment_url, vipps_payment_created_at: Time.current)
    payment_url
  end

  def set_pickup_dates
    @pickup_dates = [
      { id: "2026-04-01", label: "01. april" },
      { id: "2026-04-30", label: "30. april" },
      { id: "2026-03-19", label: "19. mars kl. 18:00" }
    ]
  end

  def send_confirmation_email
    if @agreement.send_email_copy && @agreement.customer_email.present?
      RentalAgreementMailer.confirmation_email(@agreement).deliver_later
    end
  end
end
