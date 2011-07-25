ruby_version = node[:ruby][:version]
ruby_source = node[:ruby][:source]
ruby_path = node[:ruby][:path]
rubygems_version = node[:rubygems][:version]
bundler_version = node[:rubygems][:bundler][:version]
rake_version = node[:rubygems][:rake][:version]

%w[ build-essential libssl-dev zlib1g-dev libreadline5-dev libxml2-dev ].each do |pkg|
  package pkg
end

remote_file "/tmp/ruby-#{ruby_version}.tar.gz" do
  owner node[:deployment][:user]
  source ruby_source
  not_if { ::File.exists?("/tmp/ruby-#{ruby_version}.tar.gz") }
end

directory ruby_path do
  owner node[:deployment][:user]
  group node[:deployment][:group]
  mode "0755"
  recursive true
  action :create
end

bash "Install Ruby" do
  cwd "/tmp"
  user node[:deployment][:user]
  code <<-EOH
  tar xzf ruby-#{ruby_version}.tar.gz
  cd ruby-#{ruby_version}
  ./configure --disable-pthread --prefix=#{ruby_path}
  make
  make install
  EOH
  not_if do
    ::File.exists?("#{ruby_path}/bin/ruby")
  end
end

remote_file "/tmp/rubygems-#{rubygems_version}.tgz" do
  owner node[:deployment][:user]
  source "http://production.cf.rubygems.org/rubygems/rubygems-#{rubygems_version}.tgz"
  not_if { ::File.exists?("/tmp/rubygems-#{rubygems_version}.tgz") }
end

bash "Install RubyGems" do
  cwd "/tmp"
  user node[:deployment][:user]
  code <<-EOH
  tar xzf rubygems-#{rubygems_version}.tgz
  cd rubygems-#{rubygems_version}
  #{ruby_path}/bin/ruby setup.rb
  EOH
  not_if do
    ::File.exists?("#{ruby_path}/bin/gem") &&
        system("#{ruby_path}/bin/gem -v | grep -q '#{rubygems_version}$'")
  end
end

gem_package "bundler" do
  version bundler_version
  gem_binary "#{ruby_path}/bin/gem"
end

gem_package "rake" do
  version rake_version
  gem_binary "#{ruby_path}/bin/gem"
end

# The default chef installed with Ubuntu 10.04 does not support the "retries" option
# for gem_package. It may be a good idea to add/use that option once the ubuntu
# chef package gets updated.
%w[ rack eventmachine thin sinatra mysql pg].each do |gem|
  gem_package gem do
    gem_binary "#{ruby_path}/bin/gem"
  end
end
