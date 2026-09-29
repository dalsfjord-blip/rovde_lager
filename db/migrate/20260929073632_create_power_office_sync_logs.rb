class CreatePowerOfficeSyncLogs < ActiveRecord::Migration[8.1]
  def change
    create_table :power_office_sync_logs do |t|
      t.references :rental_agreement, null: false, foreign_key: true
      t.string :step
      t.string :status
      t.text :detail

      t.timestamps
    end
  end
end
