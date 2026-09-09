class StorageItem < ApplicationRecord
  belongs_to :rental_agreement

  validates :meters, numericality: { greater_than: 0 }
  validate :registration_or_description_present

  private

  def registration_or_description_present
    unless registration_number.present? || description.present?
      errors.add(:base, "Må ha enten registreringsnummer eller beskrivelse")
    end
  end
end
