require 'spec_helper'

describe "A simple Sinatra app being staged" do
  describe "unbundled" do
    before :each do
      @app_fix = VCAP::Stager::Spec::AppFixture.new(:sinatra_trivial)
    end

    it "is packaged with a startup script" do
      @app_fix.stage(:sinatra) do |staged_dir|
        verify_staged_file(staged_dir, @app_fix.staged_dir, 'startup')
      end
    end
  end

  describe "when bundled" do
    before :each do
      @app_fix = VCAP::Stager::Spec::AppFixture.new(:sinatra_gemfile)
    end

    it "is packaged with a startup script" do
      @app_fix.stage(:sinatra) do |staged_dir|
        verify_staged_file(staged_dir, @app_fix.staged_dir, 'startup')
      end
    end
  end
end
