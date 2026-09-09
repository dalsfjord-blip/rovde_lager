class CreateRentalAgreements < ActiveRecord::Migration[8.1]
  def change
    create_table :rental_agreements do |t|
      t.string :customer_name
      t.string :customer_phone
      t.string :customer_email
      t.date :pickup_date
      t.boolean :special_needs
      t.text :special_needs_notes
      t.decimal :total_meters
      t.decimal :total_price
      t.string :payment_method
      t.string :payment_status
      t.boolean :contract_approved
      t.boolean :send_email_copy
      t.string :reference_number

      t.timestamps
    end
  end
end
