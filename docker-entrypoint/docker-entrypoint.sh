#!/bin/bash

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
    echo "Starting Apache web server"
    apache2-foreground
}

setup_config_file() {
    if [ ! -e wp-config-sample.php ]; then
        echo ">>> Wordpress sample config file not found. Please setup wp-config.php manually"
        run_web_server
    else
        echo ">>> Creating wp-config.php"
        yes | cp -rf wp-config-sample.php wp-config.php
        wp config set DB_HOST "${WORDPRESS_DB_HOST}" --add --type=constant --allow-root
        wp config set DB_NAME "${WORDPRESS_DB_NAME}" --add --type=constant --allow-root
        wp config set DB_USER "${WORDPRESS_DB_USER}" --add --type=constant --allow-root
        wp config set DB_PASSWORD "${WORDPRESS_DB_PASSWORD}" --add --type=constant --allow-root
        echo ">>> Finished creating wp-config.php"
    fi
}

check_database_import() {
    if [ ! -e "${WEB_ROOT_DIR}"/"${WORDPRESS_DB_FILE}" ]; then
        echo ">>> SQL file not specified, skipping database import"
    else
        wp db import "${WEB_ROOT_DIR}"/"${WORDPRESS_DB_FILE}" --allow-root
    fi
}

replace_site_urls() {
    echo ">>> Replacing database values ${WORDPRESS_OLD_DOMAIN} with ${WORDPRESS_NEW_DOMAIN}"
    wp search-replace "${WORDPRESS_OLD_DOMAIN}" "${WORDPRESS_NEW_DOMAIN}" --allow-root
}

check_htaccess() {
    echo ">>> Checking if .htaccess need to be touched"
    if [ ! -e .htaccess ]; then
        echo ">>> Copying .htaccess"
        cp /tmp/.htaccess "${WEB_ROOT_DIR}"
    else
        echo ">>> Current .htaccess will be not touched"
    fi
}

import_wordpress() {
    echo ">>> Importing existing installation of Wordpress"
    check_exit_status setup_config_file
    check_exit_status check_database_import
    check_exit_status replace_site_urls
    check_exit_status check_htaccess
    check_exit_status run_web_server
}

install_wordpress() {
    echo ">>> Wordpress installation not found in ${WEB_ROOT_DIR} - installing..."
    wp core download --locale="${WORDPRESS_LANG}" --allow-root
    cp /tmp/.htaccess "${WEB_ROOT_DIR}"
    chown -R www-data:www-data .
    echo ">>> Latest Wordpress was downloaded for language ${WORDPRESS_LANG}"
    check_exit_status run_web_server
}

echo ">>> Setting up application"

if ! [ -e index.php -a -e wp-includes/version.php ]; then
    echo ">>> Proceding to Wordpress fresh install"
    install_wordpress
else
    if [[ -z ${WORDPRESS_DB_HOST} ]] && \
       [[ -z ${WORDPRESS_DB_USER} ]] && \
       [[ -z ${WORDPRESS_DB_NAME} ]] && \
       [[ -z ${WORDPRESS_DB_PASSWORD} ]] && \
       [[ -z ${WORDPRESS_OLD_DOMAIN} ]] && \
       [[ -z ${WORDPRESS_NEW_DOMAIN} ]]; then

        import_wordpress
    fi
fi