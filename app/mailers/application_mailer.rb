class ApplicationMailer < ActionMailer::Base
  default from: ENV.fetch("SMTP_FROM_EMAIL", "avtale@rovdeindustripark.no")
  layout "mailer"
end
