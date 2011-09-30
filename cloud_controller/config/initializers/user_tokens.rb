require 'user_token'
UserToken.token_key = AppConfig[:keys][:token].dup
UserToken.token_expire = AppConfig[:keys][:token_expiration] || 604800 # 7 * 24 * 60 * 60 (= 1 week)
