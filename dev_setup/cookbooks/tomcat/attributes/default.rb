include_attribute "deployment"
default[:tomcat][:version] = "7.0.27"
default[:tomcat][:source]  = "http://www.us.apache.org/dist/tomcat/tomcat-7/v#{tomcat[:version]}/bin/apache-tomcat-#{tomcat[:version]}.tar.gz"
default[:tomcat][:base]    = File.join(node[:deployment][:home], "deploy", "uaa-tomcat")
