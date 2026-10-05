class PowerOfficeInvoiceSyncJob < ApplicationJob
  SERVICE_PRODUCT_CODE = "SESONGLAGRING"
  SERVICE_PRODUCT_NAME = "Sesonglagring"

  retry_on Faraday::ConnectionFailed, Faraday::TimeoutError, wait: :polynomially_longer, attempts: 5

  def perform(rental_agreement_id, client: PowerOfficeClient.new)
    agreement = RentalAgreement.find_by(id: rental_agreement_id)
    return unless agreement
    return unless agreement.business_customer?
    return if agreement.power_office_invoice_id.present?

    agreement.update!(power_office_sync_status: "processing", power_office_sync_error: nil)

    create_customer(agreement, client) unless agreement.power_office_customer_id.present?
    create_sales_order(agreement, client) unless agreement.power_office_sales_order_id.present?

    if invoicing_enabled?
      send_invoice(agreement, client)
    else
      log(agreement, step: "send_invoice", status: "skipped", detail: "POWEROFFICE_INVOICE_SEND_ENABLED er av, venter til testmiljøet er bekreftet OK.")
      agreement.update!(power_office_sync_status: "invoice_drafted")
    end
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
    agreement.update!(power_office_customer_id: customer_number(response))
    log(agreement, step: "customer", status: "success", detail: "PowerOffice kundenummer #{agreement.power_office_customer_id}")
  end

  def create_sales_order(agreement, client)
    product_id = client.ensure_service_product!(code: SERVICE_PRODUCT_CODE, name: SERVICE_PRODUCT_NAME)
    response = client.create_sales_order(
      customer_number: agreement.power_office_customer_id,
      reference: agreement.reference_number,
      lines: [
        {
          ProductId: product_id,
          Description: "Sesonglagring #{agreement.reference_number}",
          Quantity: 1,
          ProductUnitPrice: agreement.net_price
        }
      ]
    )
    agreement.update!(power_office_sales_order_id: response_id(response))
    log(agreement, step: "invoice_draft", status: "success", detail: "PowerOffice fakturautkast-ID #{agreement.power_office_sales_order_id}")
  end

  def send_invoice(agreement, client)
    client.create_and_send_invoice(
      sales_order_id: agreement.power_office_sales_order_id,
      delivery_type: "Auto",
      email: agreement.billing_email
    )
    agreement.update!(power_office_sync_status: "sending")
    log(agreement, step: "send_invoice", status: "queued", detail: "PowerOffice har satt fakturaen i sendekø (202 Accepted). Venter på bekreftelse.")
    PowerOfficeInvoiceSentStateJob.perform_later(agreement.id)
  end

  def customer_number(response)
    response["Number"] || response["number"] || response["Id"] || response["id"]
  end

  def response_id(response)
    response["Id"] || response["id"]
  end

  def invoicing_enabled?
    ActiveModel::Type::Boolean.new.cast(ENV["POWEROFFICE_INVOICE_SEND_ENABLED"])
  end

  def log(agreement, step:, status:, detail: nil)
    PowerOfficeSyncLog.create!(rental_agreement: agreement, step: step, status: status, detail: detail)
  end

  def mark_failed(rental_agreement_id, error)
    agreement = RentalAgreement.find_by(id: rental_agreement_id)
    return unless agreement

    message = error.is_a?(PowerOfficeClient::RequestError) ? "PowerOffice #{error.status}: #{error.detail}" : error.message
    agreement.update(power_office_sync_status: "failed", power_office_sync_error: message.to_s.truncate(500))
    log(agreement, step: "sync", status: "failed", detail: message.to_s.truncate(500))
  end
end
