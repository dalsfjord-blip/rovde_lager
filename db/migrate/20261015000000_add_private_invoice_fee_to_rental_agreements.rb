class AddPrivateInvoiceFeeToRentalAgreements < ActiveRecord::Migration[8.1]
  def change
    add_column :rental_agreements, :private_invoice_fee, :decimal, precision: 12, scale: 2, default: 0, null: false
  end
end
