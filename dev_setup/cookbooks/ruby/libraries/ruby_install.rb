module RubyInstall
  def cf_ruby_install(ruby_version, ruby_source_id, ruby_path, ruby_tarball_suffix)
    rubygems_version = node[:rubygems][:version]
    bundler_version = node[:rubygems][:bundler][:version]
    rake_version = node[:rubygems][:rake][:version]

    %w[ build-essential libssl-dev zlib1g-dev libreadline6-dev libxml2-dev].each do |pkg|
      package pkg
    end

    ruby_tarball_path = File.join(node[:deployment][:setup_cache], "ruby-#{ruby_version}.tar.#{ruby_tarball_suffix}")
    cf_remote_file ruby_tarball_path do
      owner node[:deployment][:user]
      id ruby_source_id
      checksum node[:ruby][:checksums][ruby_version]
    end

    directory ruby_path do
      owner node[:deployment][:user]
      group node[:deployment][:group]
      mode "0755"
      recursive true
      action :create
    end

    bash "Install Ruby #{ruby_path}" do
      cwd File.join("", "tmp")
      user node[:deployment][:user]
      code <<-EOH
      # work around chef's decompression of source tarball before a more elegant
      # solution is found
      if [ "#{ruby_tarball_suffix}" = "bz2" ];then
        tar xf #{ruby_tarball_path}
      else
        tar xzf #{ruby_tarball_path}
      fi
      cd ruby-#{ruby_version}
      # See http://deadmemes.net/2011/10/28/rvm-install-fails-on-ubuntu-11-10/
      sed -i 's/\\(OSSL_SSL_METHOD_ENTRY(SSLv2[^3]\\)/\\/\\/\\1/g' ./ext/openssl/ossl_ssl.c
      ./configure --disable-pthread --prefix=#{ruby_path}
      make
      make install
      EOH
    end

    rubygem_tarball_path = File.join(node[:deployment][:setup_cache], "rubygems-#{rubygems_version}.tgz")
    cf_remote_file rubygem_tarball_path do
      owner node[:deployment][:user]
      id node[:rubygems][:id]
      checksum node[:rubygems][:checksum]
    end

    bash "Install RubyGems #{ruby_path}" do
      cwd File.join("", "tmp")
      user node[:deployment][:user]
      code <<-EOH
      tar xzf #{rubygem_tarball_path}
      cd rubygems-#{rubygems_version}
      #{File.join(ruby_path, "bin", "ruby")} setup.rb
      EOH
    end

    gem_package "bundler" do
      version bundler_version
      gem_binary File.join(ruby_path, "bin", "gem")
    end

    # The default chef installed with Ubuntu 10.04 does not support the "retries" option
    # for gem_package. It may be a good idea to add/use that option once the ubuntu
    # chef package gets updated.
    %w[ rack eventmachine thin sinatra mysql pg vmc ].each do |gem|
      gem_package gem do
        gem_binary File.join(ruby_path, "bin", "gem")
      end
    end
  end
end

class Chef::Recipe
  include RubyInstall
end
