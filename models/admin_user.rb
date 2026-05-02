require 'bcrypt'

class AdminUser
  include Mongoid::Document
  include Mongoid::Timestamps::Short

  store_in collection: 'admin_users'

  field :n,  as: :name,          type: String
  field :ph, as: :password_hash, type: String

  validates_presence_of :name
  validates_presence_of :password_hash
  validates_uniqueness_of :name

  def password=(plain)
    self.password_hash = BCrypt::Password.create(plain)
  end

  def authenticate(plain)
    BCrypt::Password.new(password_hash) == plain
  rescue BCrypt::Errors::InvalidHash
    false
  end
end
