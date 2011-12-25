ruby_version = node[:ruby18][:version]
ruby_source = node[:ruby18][:source]
ruby_path = node[:ruby18][:path]
rubygems_version = node[:rubygems][:version]
bundler_version = node[:rubygems][:bundler][:version]
rake_version = node[:rubygems][:rake][:version]

include_recipe "ruby::default"

bash "Install Ruby 1.8" do
  cwd File.join("", "tmp")
  user node[:deployment][:user]
  code <<-EOH
  tar xzf ruby-#{ruby_version}.tar.gz
  cd ruby-#{ruby_version}
  ./configure --disable-pthread --prefix=#{ruby_path}
  make
  make install
  EOH
  not_if do
    ::File.exists?(File.join(ruby_path, "bin", "ruby"))
  end
end

bash "Install RubyGems for Ruby 1.8" do
  cwd File.join("", "tmp")
  user node[:deployment][:user]
  code <<-EOH
  tar xzf rubygems-#{rubygems_version}.tgz
  cd rubygems-#{rubygems_version}
  #{File.join(ruby_path, "bin", "ruby")} setup.rb
  EOH
  not_if do
    ::File.exists?(File.join(ruby_path, "bin", "gem")) &&
        system("#{File.join(ruby_path, "bin", "gem")} -v | grep -q '#{rubygems_version}$'")
  end
end
