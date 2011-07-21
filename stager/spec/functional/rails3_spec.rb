require 'spec_helper'

describe "A Rails 3 application being staged" do
  it "FIXME doesn't load the schema when there are no migrations"
  it "FIXME doesn't package all the gems if production mode requires git sources"

  before :each do
    @app_fix = VCAP::Stager::Spec::AppFixture.new(:rails3_nodb)
  end

  it "is packaged with a startup script" do
    @app_fix.stage(:rails3) do |staged_dir|
      verify_staged_file(staged_dir, @app_fix.staged_dir, 'startup')
    end
  end

  it "does not receive the static_assets plugin by default" do
    @app_fix.stage :rails3 do |staged_dir|
      plugin_dir = staged_dir.join('app', 'vendor', 'plugins', 'serve_static_assets')
      plugin_dir.should_not be_directory
    end
  end

  describe "which bundles 'thin'" do
    before :each do
      @app_fix = VCAP::Stager::Spec::AppFixture.new(:rails3_no_assets)
    end

    it "is started with `rails server thin`" do
      @app_fix.stage(:rails3) do |staged_dir|
        verify_staged_file(staged_dir, @app_fix.staged_dir, 'startup')
      end
    end
  end

  describe "which disables static asset support" do
    before :each do
      @app_fix = VCAP::Stager::Spec::AppFixture.new(:rails3_no_assets)
    end

    it "is packaged with the appropriate Rails plugin" do
      @app_fix.stage :rails3 do |staged_dir|
        plugin_dir = staged_dir.join('app', 'vendor', 'plugins')
        env = staged_dir.join('app', 'config', 'environments', 'production.rb')
        env_settings = File.open(env) { |f| f.read }
        config = 'config.serve_static_assets = false'
        env_settings.should include(config)
        plugin_dir.join('serve_static_assets').should be_directory
        plugin_dir.join('serve_static_assets', 'init.rb').should be_readable
      end
    end
  end

  describe "which uses git URLs for its test dependencies" do
    before :each do
      @app_fix = VCAP::Stager::Spec::AppFixture.new(:rails3_gitgems)
    end

    it "installs the development and production gems" do
      pending
      stage :rails3 do |staged_dir|
        verify_staged_file(staged_dir, @app_fix.staged_dir, 'startup')
        rails = staged_dir.join('app', 'rubygems', 'ruby', '1.8', 'gems', 'rails-3.0.5')
        rails.should be_directory
      end
    end
  end
end

