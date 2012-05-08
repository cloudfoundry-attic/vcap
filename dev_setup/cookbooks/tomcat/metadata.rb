%w{ java }.each do |cb|
  depends cb
end

%w{ debian ubuntu centos redhat fedora }.each do |os|
  supports os
end
