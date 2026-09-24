class AddBusinessCustomerToRentalAgreements < ActiveRecord::Migration[8.1]
  def change
    add_column :rental_agreements, :business_customer, :boolean, default: false, null: false
  end
end
