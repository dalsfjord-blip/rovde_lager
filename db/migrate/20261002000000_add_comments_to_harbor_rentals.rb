class AddCommentsToHarborRentals < ActiveRecord::Migration[8.1]
  def change
    add_column :harbor_rentals, :comments, :text
  end
end
