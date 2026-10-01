class HarborRentalInvoicePdf
  def initialize(harbor_rental)
    @harbor_rental = harbor_rental
  end

  def render
    Prawn::Document.new(page_size: "A4", margin: 48) do |pdf|
      pdf.text "Rovde Industripark", size: 22, style: :bold
      pdf.move_down 16
      pdf.text "FAKTURA", size: 18, style: :bold
      pdf.text "Fakturanummer: #{@harbor_rental.invoice_number}"
      pdf.text "Fakturadato: #{@harbor_rental.created_at.to_date.strftime('%d.%m.%Y')}"
      pdf.text "Forfallsdato: #{@harbor_rental.invoice_due_date.strftime('%d.%m.%Y')}"
      pdf.move_down 18
      pdf.text "Fakturamottakar", style: :bold
      pdf.text @harbor_rental.billing_company_name
      pdf.text "Org.nr: #{@harbor_rental.billing_organization_number}"
      pdf.text @harbor_rental.billing_email
      pdf.move_down 18
      pdf.text "Referanse: #{@harbor_rental.reference_number}"
      pdf.move_down 8
      pdf.table(item_rows, header: true, width: pdf.bounds.width) do
        row(0).font_style = :bold
        columns(2).align = :right
      end
      pdf.move_down 18
      pdf.text "Beløp ekskl. MVA: #{format_amount(@harbor_rental.net_price)}", align: :right
      pdf.text "MVA (25 %): #{format_amount(@harbor_rental.vat_amount)}", align: :right
      pdf.text "Å betale: #{format_amount(@harbor_rental.total_price_with_vat)}", align: :right, style: :bold
      pdf.move_down 24
      pdf.text "Betalingsfrist: #{@harbor_rental.invoice_due_date.strftime('%d.%m.%Y')}"
      pdf.text "Kontonummer for innbetaling: 3626 58 20780"
      pdf.text "Rovde Industripark, org.nr 987988290"
    end.render
  end

  private

  def item_rows
    [
      [ "Hamneleige", "Døgn", "Beløp ekskl. MVA" ],
      [ "Hamneleige", @harbor_rental.days.to_s, format_amount(@harbor_rental.net_price) ]
    ]
  end

  def format_amount(amount)
    format("%.2f NOK", amount || 0)
  end
end
