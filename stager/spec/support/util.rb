def zip_app(dir, app_name)
  app_source_dir = fixture_path('apps', app_name, 'source')
  target_path = File.join(dir, "#{app_name}.zip")
  VCAP::Subprocess.run("cd #{app_source_dir}; zip -q -y #{target_path} -r *")
  target_path
end

def start_http_server(http_dir, opt_dirs = {})
  port = VCAP.grab_ephemeral_port
  DummyHandler.set(:upload_path, opt_dirs[:upload] || http_dir)
  DummyHandler.set(:download_path, opt_dirs[:download] || http_dir)
  http_server = VCAP::Stager::Spec::ForkedHttpServer.new(DummyHandler,
                                                         port, http_dir)
  http_server.start.wait_ready.should be_true
  http_server
end
