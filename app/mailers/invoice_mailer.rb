class InvoiceMailer < ApplicationMailer
  def invoice(agreement)
    @agreement = agreement
    attachments["faktura-#{agreement.invoice_number}.pdf"] = {
      mime_type: "application/pdf",
      content: InvoicePdf.new(agreement).render
    }

    mail(
      to: agreement.invoice_recipient_email,
      from: ENV.fetch("INVOICE_FROM_EMAIL", "faktura@rovdeindustripark.app"),
      cc: accounting_email,
      subject: "Faktura #{agreement.invoice_number} fra Rovde Industripark"
    )
  end

  def accounting_email
    ENV.fetch("ACCOUNTING_EMAIL", "rovdeindustri@faktura.poweroffice.net") unless Rails.env.development?
  end

  def paid_receipt(agreement)
    @agreement = agreement
    attachments["kvittering-#{agreement.reference_number}.pdf"] = {
      mime_type: "application/pdf",
      content: InvoicePdf.new(agreement, document_type: "BETALINGSKVITTERING").render
    }

    mail(
      to: agreement.billing_email,
      from: ENV.fetch("INVOICE_FROM_EMAIL", "faktura@rovdeindustripark.app"),
      cc: ENV.fetch("ACCOUNTING_EMAIL", "rovdeindustri@faktura.poweroffice.net"),
      subject: "Betalingskvittering #{agreement.reference_number} fra Rovde Industripark"
    )
  end
end
