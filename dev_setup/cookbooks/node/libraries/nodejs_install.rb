module NodeInstall
  def cf_node_install(node_version, node_source, node_path)
    %w[ build-essential ].each do |pkg|
      package pkg
    end

    remote_file File.join(node[:deployment][:setup_cache], "node-v#{node_version}.tar.gz") do
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
      tar xzf #{File.join(node[:deployment][:setup_cache],
        "node-v#{node_version}.tar.gz") }
      cd node-v#{node_version}
      ./configure --prefix=#{node_path}
      make
      make install
      EOH
      not_if do
        ::File.exists?(File.join(node_path, "bin", "node"))
      end
    end
  end
end

class Chef::Recipe
  include NodeInstall
end

