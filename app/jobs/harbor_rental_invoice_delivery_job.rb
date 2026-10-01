class HarborRentalInvoiceDeliveryJob < ApplicationJob
  def perform(harbor_rental_id)
    harbor_rental = HarborRental.find_by(id: harbor_rental_id)
    return unless harbor_rental

    harbor_rental.with_lock do
      return if harbor_rental.invoice_sent_at.present?

      harbor_rental.update!(
        invoice_number: harbor_rental.invoice_number || HarborRental.next_invoice_number,
        invoice_due_date: harbor_rental.invoice_due_date || 14.days.from_now.to_date
      )
      HarborRentalMailer.invoice(harbor_rental).deliver_now
      harbor_rental.update!(payment_status: "invoice_sent", invoice_sent_at: Time.current)
    end
  end
end
