require 'hmac-sha1'

class UserToken
  class DecodeError < ArgumentError;end
  class << self
    attr_accessor :token_key, :token_expire

    def create(user_name)
      valid_until = (Time.now.utc + token_expire).to_i
      new(user_name, valid_until)
    end

    # Return a UserToken from an encoded string
    def decode(string)
      user_name, time, decoded_hmac = Marshal.load([string].pack('H*'))
      token = UserToken.new(user_name, time)
      token.decoded_hmac = decoded_hmac.to_s
      token
    rescue
      raise DecodeError, "Invalid UserToken data"
    end

    def hmac(*strings)
      key = UserToken.token_key
      HMAC::SHA1.new(key).update(strings.join).digest
    end

    def token_expire
      @token_expire ||= 1.week
    end
  end
  attr_reader :user_name, :valid_until, :hmac
  attr_writer :decoded_hmac

  def initialize(user_name, valid_until)
    @user_name = user_name
    @valid_until = valid_until
    @hmac = regenerate_hmac
  end

  # Double-check what is going on. Not valid if user_name or valid_until has been altered.
  # Definitely not valid if the message was tampered with.
  def valid?
    !expired? && (@hmac == regenerate_hmac) && (@decoded_hmac.nil? || @decoded_hmac == @hmac)
  end

  def expired?
    Time.now.to_i > @valid_until.to_i
  end

  def encode
    if valid?
      data = [user_name, valid_until, hmac]
      Marshal.dump(data).unpack('H*').first
    else
      raise "Attempted to encode an invalid UserToken"
    end
  end

  def to_json(options = nil)
    Yajl::Encoder.encode({"token" => encode})
  end

  # Two UserToken objects are equivalent when they have the same HMAC.
  # No invalid UserToken is ever 'equal' to anything else.
  def eql?(other)
    self.class === other && valid? && other.valid? && hmac == other.hmac
  end
  alias == eql?
  # UserTokens with identical HMACs result in identical Hash keys, etc.
  def hash
    hmac.hash
  end

  def email
    @user_name
  end

  private
  def regenerate_hmac
    self.class.hmac(@user_name, @valid_until)
  end
end
