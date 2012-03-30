include_attribute "deployment"
default[:maven][:version] = "3.0.4"
default[:maven][:source]  = "http://mirror.lividpenguin.com/pub/apache/maven/binaries/apache-maven-#{maven[:version]}-bin.tar.gz"
default[:maven][:base]    = File.join(node[:deployment][:home], "deploy", "maven")
default[:maven][:path]    = File.join(node[:maven][:base], "apache-maven-#{maven[:version]}")
