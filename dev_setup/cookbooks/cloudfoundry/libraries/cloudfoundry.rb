module CloudFoundry
  def cf_bundle_install(path)
    bash "Bundle install for #{path}" do
      cwd path
      user node[:deployment][:user]
      code <<-EOH
      #{node[:ruby][:path]}/bin/bundle install
      EOH
      only_if { ::File.exist?(File.join(path, 'Gemfile')) }
    end
  end
end

class Chef::Recipe
  include CloudFoundry
end
