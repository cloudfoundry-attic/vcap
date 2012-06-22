include_attribute "deployment"

default[:elasticsearch][:version] = "0.19.4"
default[:elasticsearch][:distribution_file] = "elasticsearch-#{elasticsearch[:version]}.tar.gz"
default[:elasticsearch][:distribution_url] = "http://github.com/downloads/elasticsearch/elasticsearch/#{default[:elasticsearch][:distribution_file]}"
default[:elasticsearch][:path] = File.join(node[:deployment][:home], "deploy", "elasticsearch")

default[:elasticsearch][:http_basic_plugin][:version] = "1.0.3"
default[:elasticsearch][:http_basic_plugin][:distribution_file] = "elasticsearch-http-basic-#{elasticsearch[:http_basic_plugin][:version]}.jar"
default[:elasticsearch][:http_basic_plugin][:distribution_url] = "http://github.com/downloads/Asquera/elasticsearch-http-basic/#{default[:elasticsearch][:http_basic_plugin][:distribution_file]}"
default[:elasticsearch][:http_basic_plugin][:path] = File.join(default[:elasticsearch][:path], "plugins", "http-basic")

default[:elasticsearch_node][:capacity] = "50"
default[:elasticsearch_node][:index] = "0"
default[:elasticsearch_node][:max_memory] = "512"
default[:elasticsearch_node][:token] = "changeelasticsearchtoken"

default[:elasticsearch][:checksum] = 'dfcfe4189e42b60b049f9b203799cf24c9c1581673eb2df96dda34a67372facd'
default[:elasticsearch][:http_basic_plugin][:checksum] = 'b7e23538301d2d21abe55f7f871946ea597cc00b57b65657937e0dd384c4f4b4'
