class StorageItemsController < ApplicationController
  before_action :load_agreement, only: [:index, :create, :add_item, :remove_item]

  def index
    @storage_items = @agreement.storage_items
  end

  def create
    @agreement.assign_attributes(agreement_params)
    
    if @agreement.save
      calculate_totals
      @agreement.save!
      redirect_to storage_items_path, notice: "Lagringsobjekt lagret!"
    else
      render :index, status: :unprocessable_entity
    end
  end

  def add_item
    @agreement.storage_items.build
    
    if @agreement.save
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.append("storage_items", 
            partial: "storage_items/item", 
            locals: { item: @agreement.storage_items.last })
        end
        format.html { redirect_to storage_items_path }
      end
    else
      render :index, status: :unprocessable_entity
    end
  end

  def remove_item
    item = @agreement.storage_items.find(params[:id])
    item.destroy
    
    calculate_totals
    @agreement.save!
    
    respond_to do |format|
      format.turbo_stream { render turbo_stream: turbo_stream.remove("storage_item_#{item.id}") }
      format.html { redirect_to storage_items_path }
    end
  end

  private

  def load_agreement
    @agreement = RentalAgreement.includes(:storage_items).last || RentalAgreement.new
  end

  def agreement_params
    params.require(:rental_agreement).permit(
      storage_items_attributes: [:id, :registration_number, :description, :meters, :_destroy]
    )
  end

  def calculate_totals
    total_meters = @agreement.storage_items.sum(&:meters) || 0
    @agreement.total_meters = total_meters
    @agreement.total_price = total_meters * 700
  end
end
