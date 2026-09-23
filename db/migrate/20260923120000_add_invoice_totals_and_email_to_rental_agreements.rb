class AddInvoiceTotalsAndEmailToRentalAgreements < ActiveRecord::Migration[8.1]
  def change
    add_column :rental_agreements, :billing_email, :string
    add_column :rental_agreements, :vat_amount, :decimal, precision: 12, scale: 2
    add_column :rental_agreements, :total_price_with_vat, :decimal, precision: 12, scale: 2
  end
end
