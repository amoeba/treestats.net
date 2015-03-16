# Helps with sending emails

module EmailHelper
  def self.send(subject, body)
    if settings.production?
      Pony.mail(
        to: "petridish@gmail.com",
        from: "petridish@gmail.com",
        subject: subject,
        body: body)
    end
  end  
end