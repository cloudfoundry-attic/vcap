include_attribute "deployment"
default[:tomcat][:version] = "7.0.27"
default[:tomcat][:source]  = "http://www.us.apache.org/dist/tomcat/tomcat-7/v#{tomcat[:version]}/bin/apache-tomcat-#{tomcat[:version]}.tar.gz"
default[:tomcat][:base]    = File.join(node[:deployment][:home], "deploy", "uaa-tomcat")
default[:tomcat][:checksum] = "c5d68a10bf99e0ea0e27551bf68d8468e93eb4758cf7628e2372ecce33c0e65a"
