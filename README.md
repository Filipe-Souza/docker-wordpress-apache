# Wordpress with Apache and PHP 7.2 in Docker

This project brings another but functionally Docker orchestration for developers mostly to setup an new or a existing
Wordpress installation without headache.

This repository holds the official image construction, that can be used to build and customize your own image.

This can look a heavy thing to do and understand at first setup, but its a one way learning. Like Docker is. :)


## How this image can be used

First of all, you must make a bind mount for keeping your Wordpress installation, whether it is a new or existing 
installation.

So, lets say you are at at some Unix system, and you wish to setup your installation at your /home/wordpress:

If you use docker-compose, you can write:

```yaml
volumes:
  - /home/wordpress/:/var/www/html
```

Or if you're using docker command line syntax:

```bash
-v /home/wordpress/:/var/www/html
```

## But, what should I do now?

For Wordpress you must setup a MySQL/MariaDB server, create a database in it and allow connections. I **STRONGLY**
recommend that you setup a MySQL/MariaDB container using [docker-compose](https://docs.docker.com/compose/overview/),
it makes more easily to setup the needed variables in wp-config.php automated configuration.

See the example [docker-compose.yml](#example-docker-compose-file) file at the end of documentation.

## Environment variables

In this image, I use environment variables to configure the start script, telling how to write the wp-config.php, wait 
for database initialization timeout, replaces old urls into new ones for news environments (from https://example.com to
http://localhost for example), and adding other specific flags in wp-config.php if needed.

### Variables needed in any type of setup (New installation or importing a existing one)

* _WORDPRESS_DB_HOST_ 
  * **Required**: Set the database host URL;
* _WORDPRESS_DB_NAME_
  * **Required**: Set the database name;
* _WORDPRESS_DB_USER_
  * **Required**: Set the database username;
* _WORDPRESS_DB_PASSWORD_
  * **Required**: Set the user database password;
* _WORDPRESS_EXTRA_FLAGS_FILE_
  * **Optional**: Set the path of the file containing extras flags to be written in wp-config.php. See 
[writing extra flags](TODO) section to configure the file correctly.

### Variables needed in a new installation of Wordpress

* _WORDPRESS_LANG_ 
  * **Required**: Set default Wordpress new installation language. This will be used to download the Wordpress Core in 
the specified language.

### Variables needed in a imported installation of Wordpress:

* _MUST_WAIT_DB_
  * **Required**: Set the amount of time in seconds that the importation process should wait for database to 
  be ready (in seconds);  
* _WORDPRESS_DB_FILE_
  * **Optional**: Set the path for SQL file to be imported. If this variable is not specified, the script will not 
  replace any data on target database; 
* _WORDPRESS_OLD_DOMAIN_
  * **Optional**: Set the old domain of Wordpress installation to be imported, that will be replaced with the value in
  _WORDPRESS_NEW_DOMAIN_ in the database. If this variable is not specified, the script will setup the constants
  [WP_SITEURL](https://codex.wordpress.org/Editing_wp-config.php#WP_SITEURL) and [WP_HOME](https://codex.wordpress.org/Editing_wp-config.php#WP_HOME)
  on wp-config.php file with the value from _WORDPRESS_NEW_DOMAIN_;
* _WORDPRESS_NEW_DOMAIN_
  * **Required**: Set the new domain to be set in database. If the _WORDPRESS_OLD_DOMAIN_ variable is not specified, the
  script will setup the constants [WP_SITEURL](https://codex.wordpress.org/Editing_wp-config.php#WP_SITEURL) and
  [WP_HOME](https://codex.wordpress.org/Editing_wp-config.php#WP_HOME) on wp-config.php file with this value.
* _WORDPRESS_TABLE_PREFIX_
  * **Optional**: Set the table prefix of your previous installation. If the _WORDPRESS_TABLE_PREFIX_ variable is set,
   the wp-config.php will be adjusted with the present value. If omitted, the default prefix wp_ is used.

### Example docker-compose file

```yaml
 
version: '3'
services:
  db:
    image: mariadb
    ports:
      - 3306:3306
    environment:
      MYSQL_ROOT_PASSWORD: mysecretpassword
      MYSQL_DATABASE: wordpress
      MYSQL_USER: root
      MYSQL_PASSWORD: myothersecretpassword
    restart: unless-stopped
  wordpress:
    image: my_wordpress_image:latest
    ports:
      - 80:80
      - 443:443
    volumes:
      - ./:/var/www/html
    environment:
      WORDPRESS_DB_HOST: db:3306
      WORDPRESS_DB_USER: root
      WORDPRESS_DB_NAME: wordpress
      WORDPRESS_DB_PASSWORD: mysecretpassword
      WORDPRESS_OLD_DOMAIN: 'https://example.com'
      WORDPRESS_NEW_DOMAIN: 'http://localhost'
      WORDPRESS_DB_FILE: example_database_script_to_import.sql
      WORDPRESS_EXTRA_FLAGS_FILE: .wp-config-flags
      MUST_WAIT_DB: 30
    depends_on:
      - db
    restart: unless-stopped
```
