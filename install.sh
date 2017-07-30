#!/bin/env bash
set -x
# MyBB installation script

# Environment variables (expected).
echo $MYBB_ADMINEMAIL
echo $MYBB_DOMAINNAME
echo $MYBB_DBNAME
echo $MYBB_DBUSERNAME
echo $MYBB_DBPASSWORD
echo $MYBB_DBHOSTNAME
echo $MYBB_DBPORT

# Configuration.
FPM_CONF="/etc/php-fpm.d"
NGINX_CONF="/etc/nginx/conf.d"
CONFIG="./mybb-config"
SOURCE="./mybb-source"
TARGET="/var/www/html"

#Preparation
if [[ ! -e ./${SOURCE} ]]; then
  mkdir ./mybb-source
  cd $SOURCE
  curl https://resources.mybb.com/downloads/mybb_1812.zip -o mybb.zip
  unzip mybb.zip "Upload/*"
  mv Upload/* .
  rm -Rf Upload mybb.zip
  cd ../
fi

# Clean-up and copy files.
rm -rf "$TARGET"/*
cp -r "$SOURCE"/* "$TARGET"/


#PHP-FPM configuration
cp -a ./${CONFIG}/mybb_fpm.conf ${FPM_CONF}/www.conf && service php-fpm restart
sudo cp -a /tmp/mybb_installation/mybb-config/mybb_fpm.conf /etc/php-fpm.d/www.conf && sudo service php-fpm restart
#Nginx vhost configuration
cp -a ./${CONFIG}/mybb_nginx.conf ${NGINX_CONF}/default.conf


#Tweak for supporting ELB DNS name as service name in Nginx
sed -ie "s/^.*hash_max_size .*$/server_names_hash_bucket_size 128;\nserver_names_hash_max_size 128;\ntypes_hash_max_size 2048;/g" /etc/nginx/nginx.conf

#Nginx configuration
sed -ie "s/MYBB_DOMAINNAME/${MYBB_DOMAINNAME}/g" ${NGINX_CONF}/default.conf
touch /var/log/nginx/access.log && chown nginx:nginx  /var/log/nginx/access.log
touch /var/log/nginx/error.log && chown nginx:nginx  /var/log/nginx/error.log

/sbin/service nginx reload


#Application configuration
sed -e "s/MYBB_ADMINEMAIL/${MYBB_ADMINEMAIL}/g" \
    -e "s/MYBB_DOMAINNAME/${MYBB_DOMAINNAME}/g" \
    "${CONFIG}/settings.php" > "${TARGET}/inc/settings.php"

sed -e "s/MYBB_DBNAME/${MYBB_DBNAME}/g" \
    -e "s/MYBB_DBUSERNAME/${MYBB_DBUSERNAME}/g" \
    -e "s/MYBB_DBPASSWORD/${MYBB_DBPASSWORD}/g" \
    -e "s/MYBB_DBHOSTNAME/${MYBB_DBHOSTNAME}/g" \
    -e "s/MYBB_DBPORT/${MYBB_DBPORT}/g" \
    "${CONFIG}/config.php" > "${TARGET}/inc/config.php"

# Initialize database.
sed -e "s/MYBB_ADMINEMAIL/${MYBB_ADMINEMAIL}/g" \
    -e "s/MYBB_DOMAINNAME/${MYBB_DOMAINNAME}/g" \
    "${CONFIG}/mybb.sql" | mysql \
    --user="$MYBB_DBUSERNAME" \
    --password="$MYBB_DBPASSWORD" \
    --host="$MYBB_DBHOSTNAME" \
    --port="$MYBB_DBPORT" \
    --database="$MYBB_DBNAME" || echo "WE ASSUME DATA ALREADY EXISTS!"

# Set proper ownership and permissions.
cd "$TARGET"
# chown www-data:www-data *
chmod 666 inc/config.php inc/settings.php
chmod 666 inc/languages/english/*.php inc/languages/english/admin/*.php

# TODO: The "uploads/" path should be mounted on an S3 bucket.
chmod 777 cache/ cache/themes/ uploads/ uploads/avatars/
chmod 777 cache/ cache/themes/ uploads/ uploads/avatars/ admin/backups/
