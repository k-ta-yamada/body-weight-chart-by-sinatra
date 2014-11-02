require 'mongoid'
# Mongoid.load!('./config/mongoid.yml', :development)
Mongoid.load!('./config/mongoid.yml')

require './models/user'
require './models/body_weight'
