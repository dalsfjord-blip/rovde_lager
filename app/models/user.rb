class User < ApplicationRecord
  has_many :harbor_rentals, dependent: :restrict_with_exception

  before_validation :normalize_phone_number

  validates :name, :email, presence: true
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, uniqueness: true
  validates :phone_number, uniqueness: true, allow_blank: true

  private

  def normalize_phone_number
    self.phone_number = phone_number.to_s.gsub(/\D/, "").presence
  end
end
