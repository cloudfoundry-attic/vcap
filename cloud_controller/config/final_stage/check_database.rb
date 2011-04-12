# This lets us fail/exit early if we are starting up without a working database.
begin
  User.where('id = 1').any?
rescue ActiveRecord::StatementInvalid => ex
  STDERR.puts "Exiting due to database error: #{ex.message}.  Make sure you have run 'rake db:migrate'"
  exit 1
end

# Disable optimistic locking..
ActiveRecord::Base.lock_optimistically = false
