class BodyWeight
  include Mongoid::Document
  include Mongoid::Timestamps

  field :date,   type: Date,  default: -> { Time.now }
  field :time,   type: Time,  default: -> { Time.now }
  field :weight, type: Float, default: 0
  field :pass,   type: String
  belongs_to :user

  def self.aggregate_of_day(name = nil)
    return { name: 'xxx', data: {} } unless %i(min max avg).include?(name)
    result =
      distinct(:date).map { |d| [d, where(date: d).send(name, :weight)] }
    { name: "#{name} of day", data: Hash[result] }
  end
end
