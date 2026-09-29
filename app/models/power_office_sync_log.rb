class PowerOfficeSyncLog < ApplicationRecord
  belongs_to :rental_agreement

  validates :step, :status, presence: true
end
