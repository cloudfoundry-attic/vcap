include_attributes "uaadb"
default[:uaadb][:host] = "localhost"

# varz password => "varzclientsecret"
default[:uaa][:varz][:secret] = "$2a$08$x7OrEpKbVFTyg.pwEmQ48.I486F08gKCi5JzhZxhAEjotnpX2kgdO"

# scim password => "scimsecret"
default[:uaa][:scim][:secret] = "$2a$08$duCE9bFm.duhfe6IrjC0Q.zIvJ9DfjBPhCcuJDj9fUVXaNjNeK5fi"

# my client password => "myclientsecret"
default[:uaa][:my][:secret] = "$2a$08$fsPmrV9zHPU14qpPR1c49.GVRL8JvW33y1qlYFwiZWX4M8vM36bBW"

# app client password => "appclientsecret"
default[:uaa][:app][:secret] = "$2a$08$Q7ZoYHasNrVzeaZ1Vjgau.2LsOJeDm7.KlCU9w3xZMDa60WYLfVom"
