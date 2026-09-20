class AddBusinessInvoiceFieldsToRentalAgreements < ActiveRecord::Migration[8.1]
  def change
    add_column :rental_agreements, :billing_company_name, :string
    add_column :rental_agreements, :billing_organization_number, :string
    add_column :rental_agreements, :invoice_sync_status, :string
    add_column :rental_agreements, :invoice_sync_error, :string
    add_column :rental_agreements, :invoice_synced_at, :datetime
    add_column :rental_agreements, :power_office_customer_id, :string
    add_column :rental_agreements, :power_office_sales_order_id, :string
    add_column :rental_agreements, :power_office_invoice_id, :string
    add_column :rental_agreements, :power_office_invoice_number, :string
  end
end
