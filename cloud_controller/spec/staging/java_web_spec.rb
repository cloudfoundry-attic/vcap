require 'spec_helper'
require 'fileutils'

describe "A Java web application being staged without a web config" do
  before do
    app_fixture :java_web_no_web_config
  end

  it "should fail" do
    lambda { stage :java_web }.should raise_error
  end
end

describe "A Java web application being staged " do
  before(:all) do
    app_fixture :java_web
  end

  it "should not be modified during staging" do
    stage :java_web do |staged_dir, source_dir|
      source_app_files = Dir.glob("#{source_dir}/**/*", File::FNM_DOTMATCH)
      staged_app_root = File.join(staged_dir, 'tomcat/webapps/ROOT')
      staged_app_files = Dir.glob("#{staged_app_root}/**/*", File::FNM_DOTMATCH)
      source_app_files.should_not == nil
      staged_app_files.should_not == nil
      source_app_files.length.should == staged_app_files.length
      source_app_files.each do |filename|
        next if File.directory?(filename)
        staged_app_file = filename.sub(/#{source_dir}/, "#{staged_app_root}")
        File.exists?(staged_app_file).should == true
        FileUtils.compare_file(filename, staged_app_file).should == true
      end
    end
  end

end
