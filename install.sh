#!/bin/env bash

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
NGINX_CONF="/etc/nginx/conf.d"
CONFIG="./mybb-config"
SOURCE="./mybb-source"
TARGET="/var/www/html"

#Preparation
if [[ ! -e ./${SOURCE} ]]; then
  mkdir ./mybb-source
fi
cd $SOURCE
curl https://resources.mybb.com/downloads/mybb_1812.zip -o mybb.zip
unzip mybb.zip "Upload/*"
mv Upload/* .
rm -Rf Upload mybb.zip
cd ../

# Clean-up and copy files.
rm -rf "$TARGET"/*
cp -r "$SOURCE"/* "$TARGET"/

# Prepare and copy dynamic configuration files.

cp -a ./${CONFIG}/mybb_nginx.conf $NGINX_CONF/default.conf
sed -e "s/MYBB_DOMAINNAME/${MYBB_DOMAINNAME}/g" "${NGINX_CONF}/default.conf"
service nginx reload

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
#sed -e "s/MYBB_ADMINEMAIL/${MYBB_ADMINEMAIL}/g" \
#    -e "s/MYBB_DOMAINNAME/${MYBB_DOMAINNAME}/g" \
#    "${CONFIG}/mybb.sql" | mysql \
#    --user="$MYBB_DBUSERNAME" \
#    --password="$MYBB_DBPASSWORD" \
#    --host="$MYBB_DBHOSTNAME" \
#    --port="$MYBB_DBPORT" \
#    --database="$MYBB_DBNAME" || echo "WE ASSUME DATA ALREADY EXISTS!"

# Set proper ownership and permissions.
cd "$TARGET"
# chown www-data:www-data *
chmod 666 inc/config.php inc/settings.php
chmod 666 inc/languages/english/*.php inc/languages/english/admin/*.php

# TODO: The "uploads/" path should be mounted on an S3 bucket.
chmod 777 cache/ cache/themes/ uploads/ uploads/avatars/
chmod 777 cache/ cache/themes/ uploads/ uploads/avatars/ admin/backups/
