#!/bin/bash
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")" && cd .. && pwd)
cd ${ROOT}

echo "-----------------------------"
echo "${PWD##*/}"
echo "-----------------------------"

read -p "Write your domain | default: localhost |: " site_url

if [ -z "${site_url}" ]; then
  URL='localhost.local'
else 
  URL=${site_url// /-};
fi

if ! echo "${URL}" | grep '^[a-zA-Z0-9]*\.[a-zA-Z]*$' >/dev/null; then
	URL="${URL}.local";
fi

while true; do

	read -p "Write your admin email: " ADMIN_EMAIL

	if echo "${ADMIN_EMAIL}" | grep '^[a-zA-Z0-9]*@[a-zA-Z0-9]*\.[a-zA-Z]*$' >/dev/null; then
		break
	else
		echo "Please write a valid email."
	fi

done

if [ ! -d "wordpress" ]; then
  mkdir "wordpress"
  chmod -R a+w "wordpress"
fi

new_database() {

	if [ -f "${ROOT}/wordpress/wp-config.php" ]; then
		docker-compose exec --user www-data phpfpm wp db create --url="${URL}" --path="${ROOT}/wordpress"
	else
		echo 'No config file found.'
	fi
}

read -p "Wordpress repository, empty to clean wordpress: " REPOSITORY

## WORDPRESS SETUP ##
if [ ! -z "${REPOSITORY}" ]; then
	echo "Local repository found. Downloading..."
	git clone $REPOSITORY "$ROOT/wordpress"

	read -p "Create wp_config and install clean database (y/n)? default y: " clean_database
	case "${clean_database}" in 
		y|Y ) new_database;;
		n|N ) break;;
		* ) new_database;;
	esac

else
	echo "New instalation..."
	docker-compose exec --user www-data phpfpm wp core download
	docker-compose exec --user www-data phpfpm wp core config --dbhost=mysql --dbname=wordpress --dbuser=root --dbpass=password

	read -p "is Multisite (y/n)? default n: " is_multisite
	case "$is_multisite" in
		y|Y ) MULTISITE=1;;
		n|N ) MULTISITE=0;;
		* ) MULTISITE=0;;
	esac

	if [ $MULTISITE -eq 1 ]; then
		echo " * Setting up multisite \"$TITLE\" at $URL"
		docker-compose exec --user www-data phpfpm wp core multisite-install --url="$URL" --title="$TITLE" --admin_user=admin --admin_password=password --admin_email="$ADMIN_EMAIL" --subdomains
		docker-compose exec --user www-data phpfpm wp super-admin add admin
	else
		echo " * Setting up \"$TITLE\" at $URL"
		docker-compose exec --user www-data phpfpm wp core install --url="$URL" --title="$TITLE" --admin_user=admin --admin_password=password --admin_email="$ADMIN_EMAIL"
	fi

fi

wordpress_updater() {
	## UPDATING COMPONENTS ##
	echo "Updating WordPress"
	docker-compose exec --user www-data phpfpm wp core update
	docker-compose exec --user www-data phpfpm wp core update-db
}

read -p "Update Wordpress? (y/n)? default y: " is_multisite
case "$is_multisite" in 
	y|Y ) wordpress_updater;;
	n|N ) break;;
	* ) wordpress_updater;;
esac

read -p "Write URL: $URL on hosts (y/n)? default n: " write_hosts
case "${write_hosts}" in 
	y|Y ) echo "127.0.0.1 $URL" | sudo tee -ai /private/etc/hosts;;
esac

echo "All done!"
