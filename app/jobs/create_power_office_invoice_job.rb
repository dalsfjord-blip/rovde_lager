class CreatePowerOfficeInvoiceJob < ApplicationJob
  retry_on Faraday::ConnectionFailed, Faraday::TimeoutError, wait: :polynomially_longer, attempts: 3

  def perform(rental_agreement_id, client: PowerOfficeClient.new)
    agreement = RentalAgreement.find(rental_agreement_id)
    return if agreement.power_office_invoice_id.present?

    agreement.update!(invoice_sync_status: "processing", invoice_sync_error: nil)

    create_customer(agreement, client) unless agreement.power_office_customer_id.present?
    create_sales_order(agreement, client) unless agreement.power_office_sales_order_id.present?
    create_invoice(agreement, client)
  rescue PowerOfficeClient::RequestError => error
    raise Faraday::ConnectionFailed, error.message if error.retryable

    mark_failed(rental_agreement_id, error)
  rescue PowerOfficeClient::ConfigurationError => error
    mark_failed(rental_agreement_id, error)
  rescue ActiveRecord::RecordNotFound
    nil
  end

  private

  def create_customer(agreement, client)
    response = client.create_customer(
      name: agreement.billing_company_name,
      organization_number: agreement.billing_organization_number,
      email: agreement.billing_email
    )
    agreement.update!(power_office_customer_id: response_id(response))
  end

  def create_sales_order(agreement, client)
    response = client.create_sales_order(
      customer_id: agreement.power_office_customer_id,
      description: "Sesonglagring #{agreement.reference_number}",
      unit_price: agreement.net_price
    )
    agreement.update!(power_office_sales_order_id: response_id(response))
  end

  def create_invoice(agreement, client)
    response = client.invoice_sales_order(agreement.power_office_sales_order_id)
    agreement.update!(
      power_office_invoice_id: response_id(response),
      power_office_invoice_number: response["InvoiceNumber"] || response["invoiceNumber"],
      invoice_sync_status: "sent",
      invoice_sync_error: nil,
      invoice_synced_at: Time.current
    )
  end

  def response_id(response)
    response["Id"] || response["id"] || response.fetch("InvoiceId", response["invoiceId"])
  end

  def mark_failed(rental_agreement_id, error)
    message = error.is_a?(PowerOfficeClient::RequestError) ? "PowerOffice #{error.status}: #{error.detail}" : error.message
    RentalAgreement.find_by(id: rental_agreement_id)&.update(invoice_sync_status: "failed", invoice_sync_error: message.truncate(500))
  end
end
