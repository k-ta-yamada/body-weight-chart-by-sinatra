class BodyWeight
  include Mongoid::Document
  include Mongoid::Timestamps

  field :date,   type: Date,  default: -> { Time.now }
  field :time,   type: Time,  default: -> { Time.now }
  field :weight, type: Float, default: 0
  field :pass,   type: String

  class << self
    def distinct_date
      distinct(:date).reverse[0..6]
    end

    def min_weights
      result = {}
      distinct_date.each do |date|
        result[date] = where(date: date).min(:weight)
      end
      result
    end

    def max_weights
      result = {}
      distinct_date.each do |date|
        result[date] = where(date: date).max(:weight)
      end
      result
    end

    def avg_weights
      result = {}
      distinct_date.each do |date|
        result[date] = where(date: date).avg(:weight)
      end
      result
    end
  end
end
