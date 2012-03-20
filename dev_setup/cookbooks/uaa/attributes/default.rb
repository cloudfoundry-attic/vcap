include_attributes "uaadb"
default[:uaadb][:host] = "localhost"

# scim password => "scimsecret"
default[:uaa][:scim][:secret] = "$2a$08$duCE9bFm.duhfe6IrjC0Q.zIvJ9DfjBPhCcuJDj9fUVXaNjNeK5fi"

# my client password => "myclientsecret"
default[:uaa][:my][:secret] = "$2a$08$fsPmrV9zHPU14qpPR1c49.GVRL8JvW33y1qlYFwiZWX4M8vM36bBW"

# app client password => "appclientsecret"
default[:uaa][:app][:secret] = "$2a$08$Q7ZoYHasNrVzeaZ1Vjgau.2LsOJeDm7.KlCU9w3xZMDa60WYLfVom"

# cloud controller client secret is the bcrypted password
# uaa expects it bcrypted, but client must have it in the clear
default[:uaa][:cloud_controller][:secret] = "$2a$08$BoWTL27.xae6li/bF3pybOGkEPk8v9LBwudhyuPc4DvvrFS4.TKv6"
default[:uaa][:cloud_controller][:password] = "cloudcontrollersecret"

default[:uaa][:jwt_secret] = "uaa_jwt_secret"

default[:uaa][:batch][:username] = "batch_user"
default[:uaa][:batch][:secret] = "batch_password"
