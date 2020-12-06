#!/usr/bin/env bash

msg() {
    echo -E "$1"
}

# Display environment variables
echo -e "Variables:
\\t- TZ=${TZ}
\\t- HTPASSWD=${HTPASSWD}
\\t- HTPASSWD_USER=${HTPASSWD_USER}
\\t- HTPASSWD_PW=${HTPASSWD_PW}"

if [ "$( grep -rni "$TZ" /etc/php7/conf.d/zzz_custom.ini | wc -l )" -eq 0 ]; then
    msg "Configure timezone for PHP..."
    echo "$TZ\"" >> /etc/php7/conf.d/zzz_custom.ini
fi

msg "Make config directories..."
mkdir -p /config/{nginx,h5ai}

# Locations of configuration files
orig_nginx="/etc/nginx/conf.d/h5ai.conf"
orig_h5ai="/usr/share/h5ai/_h5ai"
conf_nginx="/config/nginx/h5ai.conf"
conf_h5ai="/config/h5ai/_h5ai"
conf_htpwd="/config/nginx/.htpasswd"
options_file="/private/conf/options.json"

msg "Check configuration files for Nginx..."
if [ ! -f "$conf_nginx" ]; then
    msg "Copy original setup files to /config folder..."
    rm -rf $conf_nginx
    cp -arf $orig_nginx $conf_nginx
else
    msg "User setup files found: $conf_nginx"
    msg "Remove image's default setup files and copy the previous version..."
fi
rm -f $orig_nginx
ln -s $conf_nginx $orig_nginx

msg "Check configuration files for h5ai..."
if [ ! -d "$conf_h5ai" ]; then
    msg "Copy original setup files to /config folder..."
    rm -rf $conf_h5ai
    cp -arf $orig_h5ai $conf_h5ai
else
    msg "User setup files found: $conf_h5ai"

    msg "Check if h5ai version updated..."
    new_ver=$(head -n 1 $orig_h5ai$options_file | awk '{print $3}' | sed 's/[^0-9]//g')
    pre_ver=$(head -n 1 $conf_h5ai$options_file | awk '{print $3}' | sed 's/[^0-9]//g')
    if [ $new_ver -gt $pre_ver ]; then
		msg "New version detected. Make existing options.json backup file..."
		cp $conf_h5ai$options_file /config/$(date '+%Y%m%d_%H%M%S')_options.json.bak

		msg "Remove existing h5ai files..."
		rm -rf $conf_h5ai

		msg "Copy the new version..."
		rm -rf $conf_h5ai
		cp -arf $orig_h5ai $conf_h5ai
	fi

    msg "Remove image's default setup files and copy the existing version..."
fi
rm -rf $orig_h5ai
ln -s $conf_h5ai $orig_h5ai

msg "Set ownership to make Nginx can read h5ai files..."
chown -R nginx:nogroup $conf_h5ai

msg "Set permission for caching..."
chmod -R 777 $conf_h5ai/public/cache
chmod -R 777 $conf_h5ai/private/cache

# If an user wants to set htpasswd
if [ "$HTPASSWD" = "true" ]; then
    htpasswd -b -c "$conf_htpwd" "$HTPASSWD_USER" "$HTPASSWD_PW"
    cp -arf /h5ai_htpasswd.conf /config/nginx/h5ai.conf
fi

supervisord -c /etc/supervisor/conf.d/supervisord.conf
