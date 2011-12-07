require 'rest-client'
file = File.new('test.zip','rb')
upload_data = {:_method => 'put', :application => file, :resources => nil}
RestClient.post 'localhost:3200/uploads/4567/application', upload_data
