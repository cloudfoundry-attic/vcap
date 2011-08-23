# PHP Support

## Architecture

PHP applications are deployed using Apache and mod_php. For each CloudFoundry instance of the application, an Apache instance is started.

## Demo: Installing Wordpress ##
The Wordpress CMS can be run using CloudFoundry PHP support with very minimal changes.

Steps to get the application to run:

1. <code>curl -O http://wordpress.org/latest.tar.gz</code>
2. <code>tar -xzf latest.tar.gz</code>
3. <code>rm latest.tar.gz</code>
4. <code>cd wordpress</code>
5. <code>echo "<?php" > wp-salt.php</code>
6. <code>curl https://api.wordpress.org/secret-key/1.1/salt/ >> wp-salt.php</code>
7. Create wp-config.php, and set it to:

		<?php
		$services = getenv("VCAP_SERVICES");
		$services_json = json_decode($services,true);
		$mysql_config = $services_json["mysql-5.1"][0]["credentials"];

		// ** MySQL settings from resource descriptor ** //
		define('DB_NAME', $mysql_config["name"]);
		define('DB_USER', $mysql_config["user"]);
		define('DB_PASSWORD', $mysql_config["password"]);
		define('DB_HOST', $mysql_config["hostname"]);
		define('DB_PORT', $mysql_config["port"]);

		define('DB_CHARSET', 'utf8');
		define('DB_COLLATE', '');
		define ('WPLANG', '');
		define('WP_DEBUG', false);

		require('wp-salt.php');

		$table_prefix  = 'wp_';

		/* That's all, stop editing! Happy blogging. */

		/** Absolute path to the WordPress directory. */
		if ( !defined('ABSPATH') )
			define('ABSPATH', dirname(__FILE__) . '/');

		/** Sets up WordPress vars and included files. */
		require_once(ABSPATH . 'wp-settings.php');
8. <code>vmc push wordpresscf --url wordpresscf.vcap.me -n</code>
9. <code>vmc create-service mysql --bind wordpresscf</code>
10. Visit http://wordpresscf.vcap.me and enjoy your Wordpress install!