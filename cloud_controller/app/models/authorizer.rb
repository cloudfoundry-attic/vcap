module CollabSpaces

  class Authorizer


    class << self

      def can(user, operation, resource, org, project)

        @config_filename = File.expand_path('../../../config/rules.json', __FILE__)
        @config_file = File.new(@config_filename, "r")


        if(org.nil?)
          org="all"
        end

        if(project.nil?)
          project="all"
        end

        CloudController.logger.debug "user " + user.to_s + " class " + user.class.to_s
        CloudController.logger.debug "operation " + operation.to_s + " class " +  operation.class.to_s
        CloudController.logger.debug "resource " + resource.to_s + " class " +  resource.class.to_s
        CloudController.logger.debug "org " + org.to_s + " class " +  org.class.to_s
        CloudController.logger.debug "project " + project.to_s + " class " +  project.class.to_s

        begin
          CloudController.logger.debug "Config file is " + @config_file.path

          if File.exists?(@config_file)

            @az_rules = Yajl::Parser.parse(@config_file, :symbolize_keys => true)

          end
        rescue => ex
          $stderr.puts %[FATAL: Exception encountered while loading config file: #{ex}\n#{ex.backtrace.join("\n")}]
          exit 1
        end

        rule_letter=""

        if(operation == :create)
          rule_letter = "c"
        elsif(operation == :delete)
          rule_letter = "d"
        end

        permission_key = ""

        #Can user create this resource
        if(resource.to_s == "App")
          permission_key = "apps/*"
        end

        CloudController.logger.debug "User is "  + user.email
        CloudController.logger.debug "Rules set "  + @az_rules.to_s
        CloudController.logger.debug "Roles for org and project " + @az_rules[org.to_sym][project.to_sym][:roles].to_s

        if(!@az_rules[org.to_sym][project.to_sym][:roles].nil? && !rule_letter.empty?)
          #For each role, search for if the operation is allowed

          @az_rules[org.to_sym][project.to_sym][:roles].each do |role, role_info|

            users = role_info[:users]

            CloudController.logger.debug "Users for the role " + role.to_s + " is " + users.to_s + " user email is " + user.email

            found_user = false

            if(!users.empty? && users.include?(user.email))

              CloudController.logger.debug "Found user " + user.email + " for project [" + role.to_s + "]"

              rule = role_info[:permissions][permission_key.to_sym]
              CloudController.logger.debug "Rule for "  + permission_key + " is " + rule

              if(rule.include? rule_letter)
                CloudController.logger.debug "User " + user.email + " is allowed operation " + operation.to_s
                break
              else
                raise CloudError.new(CloudError::FORBIDDEN)
              end

              found_user = true

            end

            if(found_user)
              raise CloudError.new(CloudError::FORBIDDEN)
            end

          end
        else

          raise CloudError.new(CloudError::FORBIDDEN)

        end


        @config_file.close

      end

    end

  end

end
