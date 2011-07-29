def verify_staged_file(test_dir, ref_dir, rel_path)
  test_file = File.join(test_dir, rel_path)
  File.exists?(test_file).should be_true

  ref_file = File.join(ref_dir, rel_path)
  File.exists?(ref_file).should be_true

  # Check mode instead?
  File.executable?(test_file).should == File.executable?(ref_file)

  test_contents = File.read(test_file)
  ref_contents  = File.read(ref_file)
  test_contents.should == ref_contents
end
