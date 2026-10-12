class DatabaseRecordsController < ApplicationController
  def index
    @query = params[:q].to_s.strip
    @agreements = RentalAgreement.includes(:storage_items, photos_attachments: :blob)

    if @query.present?
      search_term = "%#{ActiveRecord::Base.sanitize_sql_like(@query)}%"
      @agreements = @agreements.left_joins(:storage_items).where(
        "rental_agreements.customer_name ILIKE :search_term OR storage_items.registration_number ILIKE :search_term",
        search_term: search_term
      ).distinct
    end

    @agreements = @agreements.order(created_at: :desc)
  end

  def destroy
    RentalAgreement.find(params[:id]).destroy!
    redirect_to database_records_path(q: params[:q]), notice: "Registreringen er slettet."
  end
end
