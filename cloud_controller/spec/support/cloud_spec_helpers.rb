module CloudSpecHelpers
  # Generate a handy header Hash.
  # At minimum it requires a User or email as the first argument.
  # Optionally, you can pass a second User or email which will be the 'proxy user'.
  # Finally, if you pass a String or Hash as the third argument, it will be
  # JSON-ized and used as the request body.
  def headers_for(user, proxy_user = nil, raw_data = nil)
    headers = {}
    if user
      email = User === user ? user.email : user.to_s
      headers['HTTP_AUTHORIZATION'] = UserToken.create(email).encode
    end
    if proxy_user
      proxy_email = User === proxy_user ? proxy_user.email : proxy_user.to_s
      headers['HTTP_PROXY_USER'] = proxy_email
    end
    if raw_data
      unless String === raw_data
        raw_data = Yajl::Encoder.encode(raw_data)
      end
      headers['RAW_POST_DATA'] = raw_data
    end
    headers
  end

  # Convenience method for constructing and saving a regular user.
  def build_user(email, password = 'password')
    user = User.new :email => email
    user.set_and_encrypt_password 'password'
    user.save!
    user
  end

  # Expected to be called in a 'before' block. Ensures that there are at least two users, one an admin.
  def build_admin_and_user
    User.admins = %w[admin@example.com]
    @admin ||= build_user(User.admins.first)
    @user ||= build_user('user@example.com')
  end

  # Easier than bringing the usual Faker gem in.
  # Only 'hard-code' names in the specs that are meaningful.
  # If the name doesn't matter in real life, use a random one to indicate that.
  def random_name(length = 7)
    Digest::SHA1.hexdigest("#{Time.now}-#{rand(1_000)}").slice(0,length)
  end
end
