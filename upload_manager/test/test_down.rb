require 'rest-client'
require 'pp'
response = RestClient.get 'localhost:3200/uploads/4567/application'
pp response
