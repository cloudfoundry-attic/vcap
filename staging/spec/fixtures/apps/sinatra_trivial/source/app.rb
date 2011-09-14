require 'rubygems'
require 'sinatra'

get '/' do
  results = <<-OUT
<pre>
#{%x[gem env]}

#{%x[gem list -l -d].strip}
</pre>
  OUT
end
