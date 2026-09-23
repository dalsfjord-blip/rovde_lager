class ApplicationMailer < ActionMailer::Base
  default from: ENV.fetch("SMTP_FROM_EMAIL", "noreply@rovdelager.no")
  layout "mailer"
end
