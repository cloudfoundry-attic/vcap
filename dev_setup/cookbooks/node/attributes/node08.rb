include_attribute "deployment"
default[:node08][:version] = "0.8.1"
default[:node08][:path] = File.join(node[:deployment][:home], "deploy", "nodes", "node-#{node08[:version]}")
default[:node08][:id] = "eyJvaWQiOiI0ZTRlNzhiY2E1MWUxMjIwMDRlNGU4ZWM2ODQwNzcwNGZmMjI5%0AZDFiMmY3MSIsInNpZyI6InVQNlV5MzNhOFBtRCtZdW9tS3hwV0YzMFVmYz0i%0AfQ==%0A"
default[:node][:checksums]["0.8.1"] = "0cda1325a010ce18f68501ae68e0ce97f0094e7a282c34a451f552621643a884"
