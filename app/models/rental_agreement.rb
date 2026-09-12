class RentalAgreement < ApplicationRecord
  has_many :storage_items, dependent: :destroy
  accepts_nested_attributes_for :storage_items, allow_destroy: true
  has_many_attached :photos

  # Midlertidig utkommentert for testing
  # enum :payment_method, { vipps: "vipps", invoice: "invoice" }
  # enum :payment_status, { pending: "pending", paid: "paid" }

  before_create :generate_reference_number

  validates :customer_name, :customer_phone, :customer_email, presence: true
  validates :customer_email, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :contract_approved, inclusion: { in: [true], message: "må godkjennes" }
  validates :total_meters, :total_price, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

  private

  def generate_reference_number
    self.reference_number ||= "LAG-#{SecureRandom.hex(4).upcase}"
  end
end
