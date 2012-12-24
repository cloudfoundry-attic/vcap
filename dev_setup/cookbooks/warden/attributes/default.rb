default[:warden][:rootfs_path] = File.join("", "tmp", "warden", "rootfs")
default[:warden][:depot_path] = File.join("", "tmp", "warden", "containers")

# libaio used for mysql 5.5
default[:warden][:id][:libaio] = "eyJzaWciOiJtUnVQQUUrQzZFWE1pNk9ka0R2amx3V2dnSlE9Iiwib2lkIjoi%0ANGU0ZTc4YmNhNTFlMTIyMjA0ZTRlOTg2M2YyOGYzMDUwZDdmMTU4YzJmOTki%0AfQ==%0A"
default[:warden][:checksum][:libaio] = "471bb485f12dda3cfcb84e8809e640f8bdf859d421eb6c12d4246004919cccf0"
