jruby_version = node[:jruby][:version]
jruby_source_archive = node[:jruby][:source_archive]
jruby_source_url = node[:jruby][:source_url]
jruby_path = node[:jruby][:path]

ant_binary_archive = node[:jruby][:ant_binary_archive]
ant_binary_url = node[:jruby][:ant_binary_url]

rubygems_version = node[:rubygems][:version]
bundler_version = node[:rubygems][:bundler][:version]
rake_version = node[:rubygems][:rake][:version]

remote_file File.join("", "tmp", jruby_source_archive) do
  owner node[:deployment][:user]
  source jruby_source_url
  not_if { ::File.exists?(File.join("", "tmp", jruby_source_archive)) }
end

remote_file File.join("", "tmp", ant_binary_archive) do
  owner node[:deployment][:user]
  source ant_binary_url
  not_if { ::File.exists?(File.join("", "tmp", ant_binary_archive)) }
end

directory jruby_path do
  owner node[:deployment][:user]
  group node[:deployment][:group]
  mode "0755"
  recursive true
  action :create
end

bash "Install JRuby" do
  cwd File.join("", "tmp")
  user node[:deployment][:user]
  code <<-EOH
  tar xzf #{jruby_source_archive}
  tar xzf #{ant_binary_archive}
  cd jruby-#{jruby_version}
  cp -p build.xml build.xml.orig
  sed -e 's#<antcall target="generate-ri-cache"/>#<!--<antcall target="generate-ri-cache"/>-->#' build.xml.orig > build.xml
  rm -f build.xml.orig
  PATH=../#{node[:jruby][:ant_name]}/bin:/usr/bin:$PATH ant clean build-jruby-cext-native && cp -a . #{jruby_path}
  EOH
  not_if do
    ::File.exists?(File.join(jruby_path, "bin", "jruby"))
  end
end

remote_file File.join("", "tmp", "rubygems-#{rubygems_version}.tgz") do
  owner node[:deployment][:user]
  source "http://production.cf.rubygems.org/rubygems/rubygems-#{rubygems_version}.tgz"
  not_if { ::File.exists?(File.join("", "tmp", "rubygems-#{rubygems_version}.tgz")) }
end

bash "Install RubyGems" do
  cwd File.join("", "tmp")
  user node[:deployment][:user]
  code <<-EOH
  tar xzf rubygems-#{rubygems_version}.tgz
  cd rubygems-#{rubygems_version}
  #{File.join(jruby_path, "bin", "jruby")} setup.rb
  EOH
  not_if do
    ::File.exists?(File.join(jruby_path, "bin", "gem")) &&
        system("#{File.join(jruby_path, "bin", "gem")} -v | grep -q '#{rubygems_version}$'")
  end
end

gem_package "bundler" do
  version bundler_version
  gem_binary "#{File.join(jruby_path, 'bin', 'jruby')} -S #{File.join(jruby_path, 'bin', 'gem')}"
end

gem_package "rake" do
  version rake_version
  gem_binary "#{File.join(jruby_path, 'bin', 'jruby')} -S #{File.join(jruby_path, 'bin', 'gem')}"
end

# The default chef installed with Ubuntu 10.04 does not support the "retries" option
# for gem_package. It may be a good idea to add/use that option once the ubuntu
# chef package gets updated.
%w[ rack eventmachine thin sinatra mysql pg vmc ].each do |gem|
  gem_package gem do
    gem_binary "#{File.join(jruby_path, 'bin', 'jruby')} -S #{File.join(jruby_path, 'bin', 'gem')}"
  end
end
