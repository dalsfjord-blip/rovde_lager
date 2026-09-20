class CreatePowerOfficeInvoiceJob < ApplicationJob
  def perform(rental_agreement_id)
    agreement = RentalAgreement.find(rental_agreement_id)

    agreement.with_lock do
      return if agreement.power_office_invoice_id.present?

      agreement.update!(invoice_sync_status: "queued", invoice_sync_error: nil)
    end
  rescue ActiveRecord::RecordInvalid => error
    Rails.logger.error("PowerOffice invoice preparation failed: #{error.message}")
  end
end
