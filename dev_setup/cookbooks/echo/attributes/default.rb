include_attribute "deployment"

default[:echo][:host] = "localhost"

default[:echo_node][:capacity] = "100"
default[:echo_node][:index] = "0"
default[:echo_node][:token] = "changeechotoken"

default[:echo_server][:id] = "eyJvaWQiOiI0ZTRlNzhiY2E2MWUxMjEyMDRlNGU4NmVlYmU1OTEwNGZmMDQ3%0AYTExOGEyNiIsInNpZyI6Im9wNVBMcVZaV1lFVVZ2bkhpaDFORnBVSENjMD0i%0AfQ==%0A"
default[:echo_server][:checksum] = "a1a3e89ae72ceb8f05106ad0666e4638077591090f28797ec240ded4956b610e"
default[:echo_server][:path] = File.join(node[:deployment][:home], "deploy", "echoserver")
default[:echo_server][:port] = 5002
