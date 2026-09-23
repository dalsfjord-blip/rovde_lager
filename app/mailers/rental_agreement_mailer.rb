class RentalAgreementMailer < ApplicationMailer
  def confirmation_email(agreement)
    @agreement = agreement
    @items = agreement.storage_items.order(:registration_number)
    
    mail(
      to: agreement.customer_email,
      subject: "Bekreftelse på lagerregistrering - #{agreement.reference_number}"
    )
  end
end
