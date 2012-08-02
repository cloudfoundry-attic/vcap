include_attribute "deployment"
default[:tomcat][:version]  = "7.0.27"
default[:tomcat][:id]       = "eyJzaWciOiIrc0VmSWZDZlV6cFU1eExKaU5ianFLbjVuVFk9Iiwib2lkIjoi%0ANGU0ZTc4YmNhMTFlMTIxMDA0ZTRlN2Q1MTFmODIxMDUwMThmMWUyNjQzNzEi%0AfQ==%0A"
default[:tomcat][:base]     = File.join(node[:deployment][:home], "deploy", "uaa-tomcat")
default[:tomcat][:checksum] = "c5d68a10bf99e0ea0e27551bf68d8468e93eb4758cf7628e2372ecce33c0e65a"
