class InvoiceDeliveryJob < ApplicationJob
  # Historisk ble faktura/kvittering sendt som PDF fra faktura@rovdeindustripark.app.
  # All kundekommunikasjon om faktura og kvittering er nå PowerOffice sitt ansvar
  # (PowerOfficeInvoiceSyncJob -> CreateAndSendInvoice). Denne jobben markerer bare
  # at avtalen er klar for fakturering/kvittering og trigger PowerOffice-synken.
  def perform(rental_agreement_id, receipt: false)
    agreement = RentalAgreement.find_by(id: rental_agreement_id)
    return unless agreement
    return unless agreement.business_customer?

    agreement.with_lock do
      return if receipt && agreement.receipt_sent_at.present?
      return if !receipt && agreement.invoice_sent_at.present?

      agreement.update!(
        invoice_number: agreement.invoice_number || RentalAgreement.next_invoice_number,
        invoice_due_date: agreement.invoice_due_date || 14.days.from_now.to_date
      )
      agreement.update!(receipt ? { receipt_sent_at: Time.current } : { payment_status: "invoice_sent", invoice_sent_at: Time.current })
    end

    PowerOfficeInvoiceSyncJob.perform_later(agreement.id) if PowerOfficeClient.new.configured?
  end
end
