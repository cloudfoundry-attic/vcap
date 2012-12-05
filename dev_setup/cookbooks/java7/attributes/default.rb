include_attribute "deployment"
default[:java7][:version] = "1.7.0"
default[:java7][:java_home] = File.join(node[:deployment][:home], "deploy", "java7")
default[:java7][:path] = default[:java7][:home] + "/bin"

default[:java7][:id] = {
        "x86_64" => 'eyJzaWciOiI3K1oxZEhmT0lNdm95MHZPZXZLK0hqSVpsa2s9Iiwib2lkIjoi%0ANGU0ZTc4YmNhNjFlMTIyMjA0ZTRlOTg2NDNkOWFlMDUwYmMxODA2YTUxMDMi%0AfQ==%0A',
        "i686"   => 'eyJzaWciOiJRTTh1RnhJRWxRdDR2NTRZaThRYWRPUGFSeHM9Iiwib2lkIjoi%0ANGU0ZTc4YmNhNjFlMTIxMDA0ZTRlN2Q1MWQ5NTBlMDUwYmMxYjc1ZDZjZGEi%0AfQ==%0A'
}

default[:java7][:checksum] = {
        "x86_64" => 'c056799ed800471f83367e91c384abedb5530e13d0cd9362a25a3a905f6b9522',
        "i686"   => 'a4d6417381df32dbd861b7a48f00ec472d0bff203e76386f098134367db3395e'
}

default[:java7][:available?] = true
