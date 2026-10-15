class RentalAgreement < ApplicationRecord
  VAT_RATE = BigDecimal("0.25")
  PRIVATE_INVOICE_FEE = BigDecimal("100")

  has_many :storage_items, dependent: :destroy
  accepts_nested_attributes_for :storage_items, allow_destroy: true
  has_many_attached :photos

  before_validation :normalize_billing_organization_number
  after_create :generate_reference_number

  validates :customer_name, :customer_phone, :customer_email, presence: true
  validates :customer_email, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :contract_approved, inclusion: { in: [ true ], message: "må godkjennes" }
  validates :total_meters, :total_price, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :payment_method, inclusion: { in: %w[vipps invoice private_invoice manual] }
  validates :payment_status, inclusion: { in: %w[payment_pending capture_pending paid failed cancelled invoice_pending invoice_sent] }, allow_nil: true
  validates :vipps_reference, uniqueness: true, allow_nil: true
  validates :invoice_number, uniqueness: true, allow_nil: true
  validates :billing_company_name, :billing_organization_number, :billing_email, presence: true, if: :business_invoice?
  validates :billing_email, format: { with: URI::MailTo::EMAIL_REGEXP }, if: :business_invoice?
  validates :billing_organization_number, format: { with: /\A\d{9}\z/, message: "må bestå av ni sifre" }, if: :business_invoice?
  validate :photo_count_within_limit
  validate :invoice_requires_business_details
  validate :manual_payment_requires_private_customer

  def invoice?
    business_invoice? || private_invoice?
  end

  def business_invoice?
    payment_method == "invoice"
  end

  def private_invoice?
    payment_method == "private_invoice"
  end

  def invoice_recipient_name
    private_invoice? ? customer_name : billing_company_name
  end

  def invoice_recipient_email
    private_invoice? ? customer_email : billing_email
  end

  def business_customer?
    business_customer
  end

  def net_price
    total_price || BigDecimal("0")
  end

  def self.next_invoice_number
    "#{next_document_number("invoice")}-ROLAG"
  end

  private

  def normalize_billing_organization_number
    self.billing_organization_number = billing_organization_number.to_s.gsub(/\D/, "").presence
  end

  def invoice_requires_business_details
    return unless business_invoice?

    errors.add(:payment_method, "kan bare brukes for bedrifter") unless billing_company_name.present? && billing_organization_number.present? && billing_email.present?
  end

  def manual_payment_requires_private_customer
    errors.add(:payment_method, "kan bare brukes for privatkunder") if payment_method == "manual" && business_customer?
  end

  def photo_count_within_limit
    errors.add(:photos, "kan maksimalt inneholde 10 bilder") if photos.attachments.size > 10
  end

  def generate_reference_number
    update_column(:reference_number, "ROLAG-RE-#{self.class.next_document_number("reference")}") unless reference_number.present?
  end

  def self.next_document_number(name)
    sequence = DocumentNumberSequence.find_or_create_by!(name: name)
    sequence.with_lock do
      sequence.increment!(:current_value)
      sequence.current_value
    end
  end
end
