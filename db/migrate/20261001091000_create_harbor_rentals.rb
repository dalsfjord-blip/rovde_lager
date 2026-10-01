class CreateHarborRentals < ActiveRecord::Migration[8.1]
  def change
    create_table :harbor_rentals do |t|
      t.references :user, null: false, foreign_key: true
      t.integer :days, null: false
      t.decimal :total_price, precision: 12, scale: 2, null: false
      t.decimal :vat_amount, precision: 12, scale: 2, null: false
      t.decimal :total_price_with_vat, precision: 12, scale: 2, null: false
      t.string :payment_status, null: false
      t.string :invoice_number
      t.date :invoice_due_date
      t.datetime :invoice_sent_at
      t.string :reference_number
      t.string :billing_company_name, null: false
      t.string :billing_organization_number, null: false
      t.string :billing_email, null: false

      t.timestamps
    end

    add_index :harbor_rentals, :invoice_number, unique: true
    add_index :harbor_rentals, :reference_number, unique: true
  end
end
