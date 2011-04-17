# PHP Support

## Architecture

PHP applications are deployed using a combination of lighttpd and php-cgi. For each CloudFoundry instance of the application,
a pair of lighttpd and php-cgi instances are created.

## Demo: Installing Wordpress ##
The Wordpress CMS can be run using CloudFoundry PHP support with very minimal changes.

Steps to get the application to run:

1. <code>mkdir wordpresscf; cd wordpresscf</code>
2. <code>wget http://wordpress.org/latest.tar.gz</code>
3. <code>tar -xzf latest.tar.gz</code>
4. <code>rm latest.tar.gz</code>
5. <code>mv wordpress/* .</code>
6. <code>rm -r wordpress</code>
7. Create wp-config.php, and set it to (note that changing the keys would be a *really* good idea):

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

		/**#@+
		 * Authentication Unique Keys and Salts.
		 *
		 * Change these to different unique phrases!
		 * You can generate these using the {@link https://api.wordpress.org/secret-key/1.1/salt/ WordPress.org secret-key service}
		 * You can change these at any point in time to invalidate all existing cookies. This will force all users to have to log in again.
		 *
		 * @since 2.6.0
		 */
		define('AUTH_KEY',         'B-A+*zyVM$L}w&V-w.,5.=Lj|<)LY(oaYNh7kRZC:Lv3KxGse:/nIZ.VV/_|bw<&');
		define('SECURE_AUTH_KEY',  'e<j )h1FBdyQCm=rg01e&L+tSx>J_`&J:Wjr!t7:Gm{^]lWYfm&,zwN9/3l(Q;Ba');
		define('LOGGED_IN_KEY',    '{{|Sj:P;3A6m><er05a44KGom-bheE8u-!3C0<[-=bHhb6p@8ic~,a!<GS]rNKi&');
		define('NONCE_KEY',        'x>.$Qn)6<3Yfl9Bo8`KOD+; 2J<|kx{?I^kMunvN:dh|%=BRzsuJC!F<m|5BN!<g');
		define('AUTH_SALT',        '-+u: SaC9C7+[3Wb?$+s89h)A<PZ8w6l9[?q|X*gHiG{m#6,Fs;sI&|MQm&6&[?q');
		define('SECURE_AUTH_SALT', '%j/fc+a@f1Ftw%$Jy*~O)}}2j<!.7gh>N.hKF3c2-r(,--I3}t,[l7@:;p=U$Hxb');
		define('LOGGED_IN_SALT',   'tElqJ6L*|wbZ@g&|,+}q;fO|7,I$K,?E7~-|7;%3#KoynCl-t`J]T84M2h5wx [:');
		define('NONCE_SALT',       'mv3qj@@- mzDj457< T+CwW`_UtANx`eaA@rkgW]GBOe],g/OE HTscD{|abEy[2');
		$table_prefix  = 'wp_';
		define ('WPLANG', '');
		define('WP_DEBUG', false);

		/* That's all, stop editing! Happy blogging. */

		/** Absolute path to the WordPress directory. */
		if ( !defined('ABSPATH') )
			define('ABSPATH', dirname(__FILE__) . '/');

		/** Sets up WordPress vars and included files. */
		require_once(ABSPATH . 'wp-settings.php');
8. <code>vmc push wordpresscf --url wordpresscf.vcap.me -n</code>
9. <code>vmc create-service mysql --bind wordpresscf</code>
10. Visit http://wordpresscf.vcap.me and enjoy your Wordpress install!