require 'rest-client'
require 'pp'
response = RestClient.get 'localhost:3200/download/4567'
pp response
