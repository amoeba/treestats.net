# Helps with sending emails

module MailHelper
  def self.send(subject = "No subject", body = "No message body.")
    RestClient.post "https://api:#{ENV['MAILGUN_API_KEY']}@api.mailgun.net/v2/appe68e82dbfeaa491ba5cedaac3be5b99b.mailgun.org/messages",
    :from => "petridish@gmail.com",
    :to => "petridish@gmail.com",
    :subject => "[TreeStats] #{subject}",
    :text => body,
    :html => body
  end
end