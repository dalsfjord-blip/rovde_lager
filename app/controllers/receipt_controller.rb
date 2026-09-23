class ReceiptController < ApplicationController
  before_action :load_agreement

  def show
  end

  private

  def load_agreement
    @agreement = current_agreement
    redirect_to storage_items_path, alert: "Registrer minst ett lagringsobjekt først." unless @agreement
  end
end
