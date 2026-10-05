class PowerOfficeInvoiceSentStateJob < ApplicationJob
  MAX_ATTEMPTS = 8
  BACKOFF_SECONDS = [ 1, 4, 10, 30, 60, 120, 300, 600 ].freeze

  retry_on Faraday::ConnectionFailed, Faraday::TimeoutError, wait: :polynomially_longer, attempts: 5

  def perform(rental_agreement_id, attempt: 1, client: PowerOfficeClient.new)
    agreement = RentalAgreement.find_by(id: rental_agreement_id)
    return unless agreement
    return if agreement.power_office_invoice_id.present?
    return unless agreement.power_office_sales_order_id.present?

    state = Array(client.sent_state(sales_order_id: agreement.power_office_sales_order_id)).first

    if state.nil?
      reschedule_or_fail(agreement, attempt, "PowerOffice returnerte ingen status for salgsordren.")
      return
    end

    if state["LastErrorMessage"].present?
      mark_failed(agreement, state["LastErrorMessage"])
      return
    end

    if state["SentDateTimeOffset"].present?
      agreement.update!(
        power_office_invoice_id: state["Id"] || agreement.power_office_sales_order_id,
        power_office_invoice_number: state["InvoiceNo"],
        power_office_sync_status: "synced",
        power_office_sync_error: nil,
        power_office_synced_at: state["SentDateTimeOffset"]
      )
      log(agreement, step: "send_invoice", status: "success", detail: "PowerOffice InvoiceNo #{state["InvoiceNo"]}")
      return
    end

    reschedule_or_fail(agreement, attempt, "Fakturaen behandles fortsatt hos PowerOffice.")
  rescue PowerOfficeClient::RequestError => error
    raise Faraday::ConnectionFailed, error.message if error.retryable

    mark_failed(agreement, "PowerOffice #{error.status}: #{error.detail}")
  rescue ActiveRecord::RecordNotFound
    nil
  end

  private

  def reschedule_or_fail(agreement, attempt, detail)
    if attempt >= MAX_ATTEMPTS
      mark_failed(agreement, "Tidsavbrudd: #{detail}")
      return
    end

    wait_seconds = BACKOFF_SECONDS[attempt - 1] || BACKOFF_SECONDS.last
    PowerOfficeInvoiceSentStateJob.set(wait: wait_seconds.seconds).perform_later(agreement.id, attempt: attempt + 1)
  end

  def mark_failed(agreement, message)
    agreement.update(power_office_sync_status: "failed", power_office_sync_error: message.to_s.truncate(500))
    log(agreement, step: "send_invoice", status: "failed", detail: message.to_s.truncate(500))
  end

  def log(agreement, step:, status:, detail: nil)
    PowerOfficeSyncLog.create!(rental_agreement: agreement, step: step, status: status, detail: detail)
  end
end
