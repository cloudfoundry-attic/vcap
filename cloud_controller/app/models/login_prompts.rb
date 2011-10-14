class LoginPrompts
  class << self

    def get_prompts(organization = nil)

      if(organization.nil?)
        prompts_as_json =  {
          :prompts => {
            :email => [:id, "CloudFoundry ID (email)"],
            :password => [:hidden, "CloudFoundry password"]
          }
        }
      else
        prompts_as_json =  {
          :prompts => {
            :email => [:id, organization + " ID (email)"],
            :password => [:hidden, organization + " password"]
          }
        }
      end

      return prompts_as_json

    end

  end

end