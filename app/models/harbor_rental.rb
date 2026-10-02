class HarborRental < ApplicationRecord
  PRICE_PER_DAY = BigDecimal("1500")
  VAT_RATE = BigDecimal("0.25")

  belongs_to :user

  before_validation :normalize_billing_organization_number
  before_validation :calculate_totals
  after_create :generate_reference_number

  validates :days, numericality: { only_integer: true, greater_than_or_equal_to: 1 }
  validates :total_price, :vat_amount, :total_price_with_vat, numericality: { greater_than_or_equal_to: 0 }
  validates :payment_status, inclusion: { in: %w[invoice_pending invoice_sent] }
  validates :billing_company_name, :billing_organization_number, :billing_email, presence: true
  validates :billing_email, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :billing_organization_number, format: { with: /\A\d{9}\z/, message: "må bestå av ni sifre" }
  validates :invoice_number, :reference_number, uniqueness: true, allow_nil: true

  def self.next_invoice_number
    "#{next_document_number("harbor_invoice")}-ROHAMN"
  end

  def net_price
    total_price
  end

  private

  def calculate_totals
    return unless days.present?

    self.total_price = days * PRICE_PER_DAY
    self.vat_amount = (total_price * VAT_RATE).round(2)
    self.total_price_with_vat = total_price + vat_amount
  end

  def normalize_billing_organization_number
    self.billing_organization_number = billing_organization_number.to_s.gsub(/\D/, "").presence
  end

  def generate_reference_number
    update_column(:reference_number, "ROLAG-HAMN-#{self.class.next_document_number("harbor_reference")}")
  end

  def self.next_document_number(name)
    sequence = DocumentNumberSequence.find_or_create_by!(name: name)
    sequence.with_lock do
      sequence.increment!(:current_value)
      sequence.current_value
    end
  end
end
