include_attribute "deployment"

default[:go][:path] = File.join(node[:deployment][:home], "deploy", "go")

default[:go][:id] = "eyJzaWciOiJyNnFRYW1qa0htWXJyUDdkcm9vZFhLelp6Qmc9Iiwib2lkIjoi%0ANGU0ZTc4YmNhMTFlMTIxMDA0ZTRlN2Q1MTFmODIxMDUwZDE3NTc4MDdkYWQi%0AfQ==%0A"
default[:go][:checksum] = "29cdba7bc909df7091d81f52049de023502b5b3351cd206094f2c2d9961c0315"
