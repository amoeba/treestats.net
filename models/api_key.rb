require "securerandom"

class ApiKey
  include Mongoid::Document
  include Mongoid::Timestamps::Short

  belongs_to :account

  field :s, as: :secret, type: String

  before_create :generate_secret

  private

  def generate_secret
    self.secret = "ts_#{account_id}#{SecureRandom.hex(32)}"
  end
end
