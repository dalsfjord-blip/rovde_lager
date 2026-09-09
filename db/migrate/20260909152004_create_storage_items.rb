class CreateStorageItems < ActiveRecord::Migration[8.1]
  def change
    create_table :storage_items do |t|
      t.references :rental_agreement, null: false, foreign_key: true
      t.string :registration_number
      t.text :description
      t.decimal :meters

      t.timestamps
    end
  end
end
