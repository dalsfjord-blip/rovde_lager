class HarborRentalMailer < ApplicationMailer
  def invoice(harbor_rental)
    @harbor_rental = harbor_rental
    attachments["faktura-#{harbor_rental.invoice_number}.pdf"] = {
      mime_type: "application/pdf",
      content: HarborRentalInvoicePdf.new(harbor_rental).render
    }

    mail(
      to: harbor_rental.billing_email,
      from: ENV.fetch("INVOICE_FROM_EMAIL", "faktura@rovdeindustripark.app"),
      cc: ENV.fetch("ACCOUNTING_EMAIL", "rovdeindustri@faktura.poweroffice.net"),
      subject: "Faktura #{harbor_rental.invoice_number} frå Rovde Industripark"
    )
  end
end
