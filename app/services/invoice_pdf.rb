class InvoicePdf
  def initialize(agreement, document_type: "FAKTURA")
    @agreement = agreement
    @document_type = document_type
  end

  def render
    Prawn::Document.new(page_size: "A4", margin: 48) do |pdf|
      pdf.text "Rovde Industripark", size: 22, style: :bold
      pdf.move_down 16
      pdf.text @document_type, size: 18, style: :bold
      pdf.text "Fakturanummer: #{@agreement.invoice_number}"
      pdf.text "Fakturadato: #{@agreement.created_at.to_date.strftime('%d.%m.%Y')}"
      pdf.text "Forfallsdato: #{@agreement.invoice_due_date.strftime('%d.%m.%Y')}"
      pdf.move_down 18
      pdf.text "Fakturamottaker", style: :bold
      pdf.text @agreement.billing_company_name
      pdf.text "Org.nr: #{@agreement.billing_organization_number}"
      pdf.text @agreement.billing_email
      pdf.move_down 18
      pdf.text "Referanse: #{@agreement.reference_number}"
      pdf.move_down 8
      pdf.table(item_rows, header: true, width: pdf.bounds.width) do
        row(0).font_style = :bold
        columns(2).align = :right
      end
      pdf.move_down 18
      pdf.text "Beløp ekskl. MVA: #{format_amount(@agreement.net_price)}", align: :right
      pdf.text "MVA (25 %): #{format_amount(@agreement.vat_amount)}", align: :right
      pdf.text "Å betale: #{format_amount(@agreement.total_price_with_vat)}", align: :right, style: :bold
      pdf.move_down 24
      if @document_type == "FAKTURA"
        pdf.text "Betalingsfrist: #{@agreement.invoice_due_date.strftime('%d.%m.%Y')}"
        pdf.text "Kontonummer for innbetaling: 3626 58 20780"
      end
      pdf.text "Betalt med Vipps: #{@agreement.paid_at.strftime('%d.%m.%Y %H:%M')}" if @agreement.paid_at.present?
      pdf.text "Rovde Industripark, org.nr 987988290"
    end.render
  end

  private

  def item_rows
    [[ "Lagringsobjekt", "Meter", "Beløp ekskl. MVA" ]] + @agreement.storage_items.order(:registration_number).map do |item|
      [ item.description.presence || item.registration_number.presence || "Lagringsobjekt", item.meters.to_s, format_amount(item.meters.to_d * 700) ]
    end
  end

  def format_amount(amount)
    format("%.2f NOK", amount || 0)
  end
end
