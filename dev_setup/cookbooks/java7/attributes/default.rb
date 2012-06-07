include_attribute "deployment"
default[:java7][:version] = "1.7.0"
default[:java7][:version_flag] = "-version"
default[:java7][:oracle_home] = "/usr/lib/jvm/java-7-oracle/jre"
default[:java7][:openjdk_home] = "/usr/lib/jvm/java-7-openjdk/jre"
default[:java7][:path] = default[:java7][:openjdk_home] + "/bin"
default[:java7][:java_home] = default[:java7][:openjdk_home]
default[:java7][:available?] = false
