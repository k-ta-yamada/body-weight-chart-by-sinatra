class User
  include Mongoid::Document
  include Mongoid::Timestamps

  field :provider,   type: String
  field :uid,        type: String
  field :first_name, type: String
  field :last_name,  type: String
  field :email,      type: String
  has_many :body_weights

  def self.create_with_omniauth(auth)
    create do |user|
      user.provider   = auth['provider']
      user.uid        = auth['uid']
      user.first_name = auth['info']['first_name']
      user.last_name  = auth['info']['last_name']
      user.email      = auth['info']['email']
    end
  end
end
