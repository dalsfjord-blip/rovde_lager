class AddPowerOfficeSyncFieldsToRentalAgreements < ActiveRecord::Migration[8.1]
  def change
    add_column :rental_agreements, :power_office_customer_id, :string
    add_column :rental_agreements, :power_office_sales_order_id, :string
    add_column :rental_agreements, :power_office_invoice_id, :string
    add_column :rental_agreements, :power_office_invoice_number, :string
    add_column :rental_agreements, :power_office_sync_status, :string
    add_column :rental_agreements, :power_office_sync_error, :text
    add_column :rental_agreements, :power_office_synced_at, :datetime
    add_index :rental_agreements, :power_office_invoice_number, unique: true
  end
end
