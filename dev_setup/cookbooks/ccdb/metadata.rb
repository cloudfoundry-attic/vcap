maintainer       "VMware"
maintainer_email "support@vmware.com"
license          "Apache 2.0"
description      "Installs/Configures Cloud Controller Database"
long_description IO.read(File.join(File.dirname(__FILE__), 'README.rdoc'))
version          "0.0.1"

%w{ deployment postgresql }.each do |cb|
  depends cb
end
