include_attribute "deployment"
default[:ruby][:version] = "1.9.2-p180"
default[:ruby][:id] = "eyJzaWciOiJ5RDBXTXBNQTZ4RVRGTlo0SzBBR09tL0FkY0E9Iiwib2lkIjoi%0ANGU0ZTc4YmNhMjFlMTIxMDA0ZTRlN2Q1MTFmNTUzMDUwMTlmMzMxMGZkMjQi%0AfQ==%0A"
default[:ruby][:path] = File.join(node[:deployment][:home], "deploy", "rubies", "ruby-#{ruby[:version]}")
default[:ruby][:checksums]["1.9.2-p180"] = "9027a5abaaadc2af85005ed74aeb628ce2326441874bf3d4f1a842663cde04f4"

default[:rubygems][:version] = "1.8.24"
default[:rubygems][:id] = "eyJzaWciOiJIUk51OEJpN2pkdTVDTmVKUTlZZ1N5NGxraHc9Iiwib2lkIjoi%0ANGU0ZTc4YmNhMzFlMTIxMDA0ZTRlN2Q1MTQ3NDVmMDUwMTlmMzU5MmU4ZDki%0AfQ==%0A"
default[:rubygems][:checksum] = "4b61fa51869b3027bcfe67184b42d2e8c23fa6ab17d47c5c438484b9be2821dd"

default[:ruby][:bundler][:version] = "1.1.3"
default[:ruby][:vmc][:version] = "0.3.23"
