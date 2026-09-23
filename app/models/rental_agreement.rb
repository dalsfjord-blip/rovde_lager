class RentalAgreement < ApplicationRecord
  VAT_RATE = BigDecimal("0.25")

  has_many :storage_items, dependent: :destroy
  accepts_nested_attributes_for :storage_items, allow_destroy: true
  has_many_attached :photos

  before_validation :normalize_billing_organization_number
  before_create :generate_reference_number

  validates :customer_name, :customer_phone, :customer_email, presence: true
  validates :customer_email, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :contract_approved, inclusion: { in: [ true ], message: "må godkjennes" }
  validates :total_meters, :total_price, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :payment_method, inclusion: { in: %w[vipps invoice] }
  validates :billing_company_name, :billing_organization_number, :billing_email, presence: true, if: :invoice?
  validates :billing_email, format: { with: URI::MailTo::EMAIL_REGEXP }, if: :invoice?
  validates :billing_organization_number, format: { with: /\A\d{9}\z/, message: "må bestå av ni sifre" }, if: :invoice?
  validate :photo_count_within_limit
  validate :invoice_requires_business_details

  def invoice?
    payment_method == "invoice"
  end

  def net_price
    return BigDecimal("0") if total_price_with_vat.blank?

    total_price_with_vat / (1 + VAT_RATE)
  end

  private

  def normalize_billing_organization_number
    self.billing_organization_number = billing_organization_number.to_s.gsub(/\D/, "").presence
  end

  def invoice_requires_business_details
    return unless invoice?

    errors.add(:payment_method, "kan bare brukes for bedrifter") unless billing_company_name.present? && billing_organization_number.present? && billing_email.present?
  end

  def photo_count_within_limit
    errors.add(:photos, "kan maksimalt inneholde 10 bilder") if photos.attachments.size > 10
  end

  def generate_reference_number
    self.reference_number ||= "LAG-#{SecureRandom.hex(4).upcase}"
  end
end
