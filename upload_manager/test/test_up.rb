require 'rest-client'
file = File.new('test.zip','rb')
upload_data = {:application => file, :resources => nil}
RestClient.post 'localhost:3200/upload/4567', upload_data
