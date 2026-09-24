class RemovePowerOfficeIntegrationFromRentalAgreements < ActiveRecord::Migration[8.1]
  def change
    remove_columns :rental_agreements,
      :invoice_sync_status,
      :invoice_sync_error,
      :invoice_synced_at,
      :power_office_customer_id,
      :power_office_sales_order_id,
      :power_office_invoice_id,
      :power_office_invoice_number
  end
end
