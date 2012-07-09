include_attribute "deployment"
default[:java6][:java_home] = "/usr/lib/jvm/java-6-openjdk/jre"
default[:java6][:path] = default[:java6][:java_home] + "/bin"
