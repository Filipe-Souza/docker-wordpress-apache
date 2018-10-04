#!/bin/bash

RED='\033[0;31m'
NC='\033[0m'
YELLOW='\033[1;33m'

cd "${WEB_ROOT_DIR}" || exit

function check_exit_status {
    "$@"
    local status=$?
    if [ $status -ne 0 ]; then
        echo ">>> ERROR $1" >&2
    fi
    return $status
}

run_web_server() {
    if [ "${WORDPRESS_ENV}" = "dev" ]; then
        echo ">> Dev mode started, using php.ini for development optimization"
        cp /tmp/php-dev.ini /usr/local/etc/php/php.ini
        echo ">> Starting Apache web server"
    else
        echo ">> Starting Apache web server"
    fi

    apache2-foreground
}

setup_config_file() {
    if [ ! -e wp-config-sample.php ]; then
        echo ">> Wordpress sample config file not found. Please setup wp-config.php manually using the following info: "
        echo ">> define('DB_HOST', '${WORDPRESS_DB_HOST}');"
        echo ">> define('DB_NAME', '${WORDPRESS_DB_NAME}');"
        echo ">> define('DB_USER', '${WORDPRESS_DB_USER}');"
        echo ">> define('DB_PASSWORD', ${WORDPRESS_DB_PASSWORD}');"
        echo ">> define('WP_HOME', ${WORDPRESS_HOME_URL}');"
        echo ">> define('WP_SITEURL', ${WORDPRESS_SITEURL}');"

        run_web_server
    else
        echo ">> Creating wp-config.php, copying the sample file"
        yes | cp -rf wp-config-sample.php wp-config.php

        echo ">> Setting database constants"
        wp config set DB_HOST "${WORDPRESS_DB_HOST}" --add --type=constant --quiet --allow-root
        wp config set DB_NAME "${WORDPRESS_DB_NAME}" --add --type=constant --quiet --allow-root
        wp config set DB_USER "${WORDPRESS_DB_USER}" --add --type=constant --quiet --allow-root
        wp config set DB_PASSWORD "${WORDPRESS_DB_PASSWORD}" --add --type=constant --quiet --allow-root
        echo ">> Done setting database constants"

        if [ -z ${WORDPRESS_TABLE_PREFIX} ]; then
            echo "> Leaving the default table prefix to wp_"
        else
            echo "> Setting up ${WORDPRESS_TABLE_PREFIX} as table prefix for wp-config.php"
            wp config set table_prefix "${WORDPRESS_TABLE_PREFIX}" --add --type=variable --allow-root
        fi

        echo ">> Setting security constants"
        wp config set AUTH_KEY "$(pwgen -1 -c -n -s -y -r \`\"\'\\ 128)" --add --type=constant --quiet --allow-root
        wp config set SECURE_AUTH_KEY "$(pwgen -1 -c -n -s -y -r \`\"\'\\ 128)" --add --type=constant --quiet --allow-root
		wp config set LOGGED_IN_KEY "$(pwgen -1 -c -n -s -y -r \`\"\'\\ 128)" --add --type=constant --quiet --allow-root
		wp config set NONCE_KEY "$(pwgen -1 -c -n -s -y -r \`\"\'\\ 128)" --add --type=constant --quiet --allow-root
		wp config set AUTH_SALT "$(pwgen -1 -c -n -s -y -r \`\"\'\\ 128)" --add --type=constant --quiet --allow-root
		wp config set SECURE_AUTH_SALT "$(pwgen -1 -c -n -s -y -r \`\"\'\\ 128)" --add --type=constant --quiet --allow-root
		wp config set LOGGED_IN_SALT "$(pwgen -1 -c -n -s -y -r \`\"\'\\ 128)" --add --type=constant --quiet --allow-root
		wp config set NONCE_SALT "$(pwgen -1 -c -n -s -y -r \`\"\'\\ 128)" --add --type=constant --quiet --allow-root
		echo ">> Done setting security constants"
    fi
    echo ">>> Finished creating wp-config.php"
}

check_database_import() {
    echo ">>> Started SQL file import verification"
    if [ ! -e "${WEB_ROOT_DIR}"/"${WORDPRESS_DB_FILE}" ]; then
        echo ">> SQL file not specified, skipping database import"
    else
        echo ">> Database file specified, importing..."
        wp db import "${WEB_ROOT_DIR}"/"${WORDPRESS_DB_FILE}" --allow-root
    fi
    echo ">>> Done SQL file verification"
}

replace_site_urls() {
    if [ -z ${WORDPRESS_OLD_DOMAIN} ]; then
        echo ">>> Old URL not defined, setting URL's in wp-config.php file"
        wp config set WP_HOME "${WORDPRESS_NEW_DOMAIN}" --add --type=constant --quiet --allow-root
        wp config set WP_SITEURL "${WORDPRESS_NEW_DOMAIN}" --add --type=constant --quiet --allow-root
        echo ">>> Done setting additional URL's in wp-config.php file"
    else
        echo ">>> Replacing database values ${WORDPRESS_OLD_DOMAIN} with ${WORDPRESS_NEW_DOMAIN}"
        wp search-replace "${WORDPRESS_OLD_DOMAIN}" "${WORDPRESS_NEW_DOMAIN}" --allow-root
        echo ">>> Done replacing URL's values"
    fi
}

check_htaccess() {
    echo ">>> Checking if .htaccess need to be touched"
    if [ ! -e .htaccess ]; then
        echo ">> Copying .htaccess"
        cp /tmp/.htaccess "${WEB_ROOT_DIR}"
    else
        echo ">> Current .htaccess will be not touched"
    fi
}

wait_for_database() {
    if [ ! -z ${MUST_WAIT_DB} ]; then
        echo ">> Ok, waiting for database for ${MUST_WAIT_DB} seconds."
        sleep ${MUST_WAIT_DB}
        echo ">> Finished waiting for database."
    fi
}

additional_flags() {
    echo ">>> Checking for the wp-config-flags for additional flags"
    if [ ! -e "${WORDPRESS_EXTRA_FLAGS_FILE}" ]; then
        echo ">> Additional flags file not found, skipping."
    else
        echo ">> Additional flags file found, adding flags. This may take a while..."
        echo ">> Reading flag(s) in file"
            while IFS= read -r line; do
                declare ${line};
            done < "${WORDPRESS_EXTRA_FLAGS_FILE}"
        echo ">> Done reading flag(s) file, "

        for var in "${!WPF_@}"; do
            FLAG_NAME="$var"
            FLAG_NAME=${FLAG_NAME#"WPF_"}
            echo ">> Setting up flag ${FLAG_NAME} with value ${!var}"
            wp config set ${FLAG_NAME} ${!var} --add --type=constant --raw --quiet --allow-root --anchor="/* " --placement='before'
            echo ">> Done setting up flag"
        done
        echo ">>> Done setting up additional flags"
    fi
}

fix_permissions() {
    echo ">>> Setting permissions for files and folders"
    chown www-data:www-data  -R .

    if [ "${WORDPRESS_ENV}" = "dev" ]; then
        echo -e ">> Dev mode started, the group will have ${YELLOW}-rw-rwxr--${NC} permissions for files and ${YELLOW}-rwxrwxr-x${NC} for folders"
        echo -e ">> To edit this files, you must run ${YELLOW}chown \$USER:www-data -R .${NC} on the root directory on host"
        chgrp -R www-data ${WEB_ROOT_DIR}
        find ${WEB_ROOT_DIR} -type d -exec chmod g+rwx {} +
        find ${WEB_ROOT_DIR} -type f -exec chmod g+rwx {} +
        chown -R 1000:1000 ${WEB_ROOT_DIR}
        find ${WEB_ROOT_DIR} -type d -exec chmod u+rwx {} +
        find ${WEB_ROOT_DIR} -type f -exec chmod u+rw {} +
        find ${WEB_ROOT_DIR} -type d -exec chmod g+s {} +
    else
        echo -e ">> Prod mode started, the group will have ${YELLOW}-rw-r--r--${NC} permissions for files and ${YELLOW}-rwxr-xr-x${NC} for folders"
        find . -type d -exec chmod 755 {} \;
        find . -type f -exec chmod 644 {} \;
    fi;
    echo ">>> Done setting permissions for files and folders"
}

import_wordpress() {
    check_exit_status setup_config_file
    check_exit_status wait_for_database
    check_exit_status check_database_import
    check_exit_status replace_site_urls
    check_exit_status check_htaccess
    check_exit_status additional_flags
    check_exit_status fix_permissions
    check_exit_status run_web_server
}

install_wordpress() {
    echo ">>> Wordpress installation not found in ${WEB_ROOT_DIR} - installing..."
    wp core download --locale="${WORDPRESS_LANG}" --allow-root
    cp /tmp/.htaccess "${WEB_ROOT_DIR}"
    echo ">>> Latest Wordpress was downloaded for language ${WORDPRESS_LANG}"

    if [ -z ${WORDPRESS_DB_HOST} ] || [ -z ${WORDPRESS_DB_USER} ] || [ -z ${WORDPRESS_DB_NAME} ] || [ -z ${WORDPRESS_DB_PASSWORD} ] || [ -z ${WORDPRESS_TABLE_PREFIX} ]; then
        echo -e ">> File wp-config.php will be ${RED}not${NC} generated. You must proceed with Wordpress database setup."
    else
        echo ">> File wp-config.php will be generated for this fresh install. You must proceed with site setup."
        check_exit_status setup_config_file
    fi

    check_exit_status fix_permissions
    check_exit_status run_web_server
}

echo ">>> Setting up application"

if ! [ -e index.php -a -e wp-includes/version.php ]; then
    echo ">> Proceeding to Wordpress fresh install"
    install_wordpress
else
    echo ">> Trying to make a Wordpress install import"
    if [ -z ${WORDPRESS_DB_HOST} ] || [ -z ${WORDPRESS_DB_USER} ] || [ -z ${WORDPRESS_DB_NAME} ] || [ -z ${WORDPRESS_DB_PASSWORD} ] || [ -z ${WORDPRESS_NEW_DOMAIN} ] || [ -z ${MUST_WAIT_DB} ]; then
        echo ">> One or more variables are not set, cannot proceed with importation";
    else
        echo ">> Proceeding to Wordpress installation import"
        import_wordpress
    fi
fi
