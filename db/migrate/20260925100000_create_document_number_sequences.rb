class CreateDocumentNumberSequences < ActiveRecord::Migration[8.1]
  def change
    create_table :document_number_sequences do |t|
      t.string :name, null: false
      t.integer :current_value, null: false, default: 9_999
      t.timestamps
    end

    add_index :document_number_sequences, :name, unique: true
  end
end
