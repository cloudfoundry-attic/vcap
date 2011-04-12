unless Rails.env.test?
  if defined?(WEBrick)
    $stderr.puts "WARNING: Async features will not function under WEBrick. Use `rails server thin` for development."
  end
end
