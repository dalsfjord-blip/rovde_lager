class StorageItemsController < ApplicationController
  before_action :load_agreement, only: [:index, :create, :remove_item]

  def index
    start_agreement if params[:new].present?
    @agreement = current_agreement || RentalAgreement.new
    @agreement.storage_items.build if @agreement.storage_items.empty?
    @storage_items = @agreement.storage_items
    set_pickup_dates
  end

  def create
    @agreement.assign_attributes(agreement_params)
    calculate_totals
    set_payment_status

    if @agreement.save
      store_current_agreement(@agreement)
      redirect_to receipt_path, notice: payment_notice
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
      photos: [],
      storage_items_attributes: [:id, :registration_number, :description, :meters, :_destroy]
    )
  end

  def calculate_totals
    total_meters = @agreement.storage_items.reject(&:marked_for_destruction?).sum { |item| item.meters || 0 }
    @agreement.total_meters = total_meters
    @agreement.total_price = total_meters * 700
  end

  def set_payment_status
    @agreement.payment_status = @agreement.payment_method == "vipps" ? "paid" : "pending"
  end

  def payment_notice
    @agreement.payment_method == "vipps" ? "Betaling fullført (simulert)!" : "Faktura opprettet!"
  end

  def set_pickup_dates
    @pickup_dates = [
      { id: "2026-04-01", label: "01. april" },
      { id: "2026-04-30", label: "30. april" },
      { id: "2026-03-19", label: "19. mars kl. 18:00" }
    ]
  end
end
