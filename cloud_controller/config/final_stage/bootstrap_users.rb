# Not sure if this is the correct place to be creating what are essentially seed users.
# It seems like the right place for this is during 'rake db:seed', but this provides
# a much nicer user experience.
if AppConfig[:bootstrap_users]
  for user in AppConfig[:bootstrap_users]
    User.create_bootstrap_user(user['email'], user['password'], user['is_admin'], user['is_hashed_password'])
    CloudController.logger.info("Created user #{user['email']}")
  end
end
