couchdb_tarball_path = File.join(node[:deployment][:setup_cache], "apache-couchdb-#{node[:couchdb][:version]}.tar.gz")
admin_user = "#{node[:couchdb][:username]} = #{node[:couchdb][:password]}"
port = "port = #{node[:couchdb][:port]}"
bind_address = "bind_address = #{node[:couchdb][:host]}"
output_prefix = "#{node[:deployment][:home]}/log/couchdb."
output_prefix = output_prefix.gsub(/\//, "\\/")

cf_remote_file couchdb_tarball_path do
  owner node[:deployment][:user]
  source node[:couchdb][:source]
  checksum node[:couchdb][:checksum]
end

directory "#{node[:couchdb][:path]}" do
  owner node[:deployment][:user]
  group node[:deployment][:user]
  mode "0755"
end

%w[bin etc var].each do |dir|
  directory File.join(node[:couchdb][:path], dir) do
    owner node[:deployment][:user]
    group node[:deployment][:user]
    mode "0755"
    recursive true
    action :create
  end
end

bash "Install couchdb" do
  cwd File.join("", "tmp")
  user node[:deployment][:user]
  code <<-EOH
  tar xzf #{couchdb_tarball_path}
  cd apache-couchdb-#{node[:couchdb][:version]}
  ./configure \
     --prefix=#{node[:couchdb][:path]} \
     --with-js-lib=/usr/lib/xulrunner-devel-#{node[:xulrunner][:version]}/lib \
     --with-js-include=/usr/lib/xulrunner-devel-#{node[:xulrunner][:version]}/include
  make
  make install

  sed -i 's/^COUCHDB_USER/# COUCHDB_USER/' #{node[:couchdb][:path]}/etc/default/couchdb
  sed -i 's/^COUCHDB_STDOUT_FILE.*$/COUCHDB_STDOUT_FILE=#{output_prefix}log/' #{node[:couchdb][:path]}/etc/default/couchdb
  sed -i 's/^COUCHDB_STDERR_FILE.*$/COUCHDB_STDERR_FILE=#{output_prefix}err/' #{node[:couchdb][:path]}/etc/default/couchdb

  sed -i 's/^;port.*$/#{port}/' #{node[:couchdb][:path]}/etc/couchdb/local.ini
  sed -i 's/^;bind_address.*$/#{bind_address}/' #{node[:couchdb][:path]}/etc/couchdb/local.ini
  sed -i 's/^;admin.*$/#{admin_user}/' #{node[:couchdb][:path]}/etc/couchdb/local.ini

  EOH
  not_if do
    #::File.exists?(File.join(node[:couchdb][:path], "bin", "couchdb"))
  end
end
