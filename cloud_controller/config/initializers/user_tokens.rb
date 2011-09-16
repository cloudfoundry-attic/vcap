require 'user_token'
UserToken.token_key = AppConfig[:keys][:token].dup
UserToken.token_expire = AppConfig[:expiration][:token]

