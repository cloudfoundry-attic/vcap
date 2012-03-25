jruby_path = node[:jruby][:path]
jruby_executable_file = node[:jruby19][:executable_file]

bash "Install Wrapper script for 1.9 support on JRuby" do
  cwd File.join("", "tmp")
  user node[:deployment][:user]
  code <<-EOH
    sed -e 's/JRUBY_OPTS=""/JRUBY_OPTS="--1.9"/' #{jruby_path}/bin/jruby > #{jruby_path}/bin/#{jruby_executable_file}
    chmod +x #{jruby_path}/bin/#{jruby_executable_file}
  EOH
  not_if do
    ::File.exists?(File.join(jruby_path, "bin", jruby_executable_file))
  end
end
