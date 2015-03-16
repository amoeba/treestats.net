# Helps with sending emails

module EmailHelper
  def self.send(subject, body)
    Pony.mail(
      to: "petridish@gmail.com",
      from: "petridish@gmail.com",
      subject: subject,
      body: body)
    end  
end