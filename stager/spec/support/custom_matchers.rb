# Expects two directories to be identical in content, though not filesystem metadata.
RSpec::Matchers.define :be_recursively_identical_to do |dir|
  match do |container|
    comparison_cmd = "diff -rq #{container} #{dir} > /dev/null 2> /dev/null"
    system(comparison_cmd)
  end

  failure_message_for_should do |container|
    details = `diff -rq #{container} #{dir}`
    "expected target directory #{dir} to be recursively identical to #{container}:\n#{details}"
  end

  failure_message_for_should_not do |container|
    details = `diff -rq #{container} #{dir}`
    "expected target directory #{dir} to differ from #{container}:\n#{details}"
  end
end

# Expects a string to contain the path to a real file that is executable.
RSpec::Matchers.define :be_executable_file do
  match do |container|
    File.exists?(container) && File.executable?(container)
  end

  failure_message_for_should do |container|
    "expected target file #{container} to be executable"
  end

  failure_message_for_should_not do |container|
    "expected target file #{container} to not be executable"
  end
end

