class StorageItemsController < ApplicationController
  before_action :load_agreement, only: [:index, :create, :remove_item]

  def index
    start_agreement if params[:new].present?
    @agreement = current_agreement || RentalAgreement.new
    @agreement.storage_items.build if @agreement.storage_items.empty?
    @storage_items = @agreement.storage_items
  end

  def create
    @agreement.assign_attributes(agreement_params)
    calculate_totals

    if @agreement.storage_items.any? && @agreement.storage_items.all?(&:valid?)
      @agreement.save!(validate: false)
      store_current_agreement(@agreement)
      redirect_to contract_path, notice: "Lagringsobjekt lagret!"
    else
      @storage_items = @agreement.storage_items
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
      storage_items_attributes: [:id, :registration_number, :description, :meters, :_destroy]
    )
  end

  def calculate_totals
    total_meters = @agreement.storage_items.sum { |item| item.meters || 0 }
    @agreement.total_meters = total_meters
    @agreement.total_price = total_meters * 700
  end
end
