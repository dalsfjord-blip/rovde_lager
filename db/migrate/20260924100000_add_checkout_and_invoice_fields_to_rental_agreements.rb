class AddCheckoutAndInvoiceFieldsToRentalAgreements < ActiveRecord::Migration[8.1]
  def change
    add_column :rental_agreements, :vipps_reference, :string
    add_column :rental_agreements, :vipps_payment_url, :text
    add_column :rental_agreements, :vipps_payment_created_at, :datetime
    add_column :rental_agreements, :paid_at, :datetime
    add_column :rental_agreements, :invoice_number, :string
    add_column :rental_agreements, :invoice_due_date, :date
    add_column :rental_agreements, :invoice_sent_at, :datetime
    add_column :rental_agreements, :receipt_sent_at, :datetime

    add_index :rental_agreements, :vipps_reference, unique: true
    add_index :rental_agreements, :invoice_number, unique: true
  end
end
