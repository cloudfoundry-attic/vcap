require 'spec_helper'

describe "A Clojure application being staged" do
  before :each do
    @app_fix = VCAP::Stager::Spec::AppFixture.new(:clojure_trivial)
  end

  it "is packaged with a startup script" do
    @app_fix.stage(:clojure) do |staged_dir|
      verify_staged_file(staged_dir, @app_fix.staged_dir, 'startup')
    end
  end
end

