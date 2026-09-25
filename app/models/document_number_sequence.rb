class DocumentNumberSequence < ApplicationRecord
  validates :name, presence: true, uniqueness: true
  validates :current_value, numericality: { greater_than_or_equal_to: 9_999 }
end
