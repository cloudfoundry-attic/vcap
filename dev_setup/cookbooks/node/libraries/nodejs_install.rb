module NodeInstall
  def cf_node_install(node_version, node_source, node_path, node_npm=nil)
    %w[ build-essential ].each do |pkg|
      package pkg
    end

    tarball_path = File.join(node[:deployment][:setup_cache], "node-v#{node_version}.tar.gz")
    remote_file tarball_path do
      owner node[:deployment][:user]
      source node_source
      checksum node[:node][:checksums][node_version]
    end

    directory node_path do
      owner node[:deployment][:user]
      group node[:deployment][:group]
      mode "0755"
      recursive true
      action :create
    end

    bash "Install Node.js version " + node_version do
      cwd File.join("", "tmp")
      user node[:deployment][:user]
      code <<-EOH
      tar xzf #{tarball_path}
      cd node-v#{node_version}
      ./configure --prefix=#{node_path}
      make
      make install
      EOH
      not_if do
        ::File.exists?(File.join(node_path, "bin", "node"))
      end
    end

    minimal_npm_bundled_node_version = "0.6.3"

    if Gem::Version.new(node_version) < Gem::Version.new(minimal_npm_bundled_node_version)

      remote_file File.join("", "tmp", "npm-#{node_npm[:version]}.tgz") do
        owner node[:deployment][:user]
        source node_npm[:source]
        not_if { ::File.exists?(File.join("", "tmp", "npm-#{node_npm[:version]}.tgz")) }
      end

      directory node_npm[:path] do
        owner node[:deployment][:user]
        group node[:deployment][:group]
        mode "0755"
        recursive true
        action :create
      end

      bash "Install npm version " + node_npm[:version] do
        cwd File.join("", "tmp")
        user node[:deployment][:user]
        code <<-EOH
        package=npm-#{node_npm[:version]}
        mkdir -p $package
        tar xzf ${package}.tgz --directory=#{node_npm[:path]} --strip-components=1
        EOH
        not_if do
          ::File.exists?(File.join(node_npm[:path], "bin", "npm-cli.js"))
        end
      end
    end

  end
end

class Chef::Recipe
  include NodeInstall
end
