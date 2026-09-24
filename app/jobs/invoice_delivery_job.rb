class InvoiceDeliveryJob < ApplicationJob
  def perform(rental_agreement_id, receipt: false)
    agreement = RentalAgreement.find_by(id: rental_agreement_id)
    return unless agreement

    agreement.with_lock do
      return if receipt && agreement.receipt_sent_at.present?
      return if !receipt && agreement.invoice_sent_at.present?

      agreement.update!(
        invoice_number: agreement.invoice_number || "RIP-#{agreement.id.to_s.rjust(6, '0')}",
        invoice_due_date: agreement.invoice_due_date || 14.days.from_now.to_date
      )
      receipt ? InvoiceMailer.paid_receipt(agreement).deliver_now : InvoiceMailer.invoice(agreement).deliver_now
      agreement.update!(receipt ? { receipt_sent_at: Time.current } : { invoice_sent_at: Time.current })
    end
  end
end
