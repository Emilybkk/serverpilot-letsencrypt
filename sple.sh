#!/bin/bash
#################################################
#						#
#	This script automates the installation	#
#	of Let's Encrypt SSL certificates on	#
#	your ServerPilot free plan		#
#						#
#################################################


theAction=$1
domainName=$2
appName=$3
spAppRoot="/srv/users/serverpilot/apps/$appName"
domainType=$4
spSSLDir="/etc/nginx-sp/vhosts.d/"
# Install Let's Encrypt libraries if not found
if ! hash letsencrypt 2>/dev/null; then
	lecheck=$(eval "apt-cache show letsencrypt 2>&1")
	if [[ "$lecheck" == *"No"* ]]
		then
		sudo wget --no-check-certificate https://dl.eff.org/certbot-auto  &>/dev/null
		sudo chmod a+x certbot-auto  &>/dev/null
		sudo mv certbot-auto /usr/local/bin/letsencrypt  &>/dev/null
	else
		sudo apt-get install -y letsencrypt  &>/dev/null
	fi
fi

# Add a cron job for auto-ssl renewal
if crontab -l | xargs grep -l '@monthly "sudo service nginx-sp stop && yes | letsencrypt renew &>/dev/null && service nginx-sp start && service nginx-sp reload && service cron reload"'; then
	(crontab -l ; echo "@monthly \"sudo service nginx-sp stop && yes | letsencrypt renew &>/dev/null && service nginx-sp start && service nginx-sp reload && service cron reload\"")| crontab -
fi

if [ -z "$theAction" ]
	then
	echo -e "\e[31mPlease specify the task. Should be either install or uninstall\e[39m"
	exit
fi

if [ -z "$domainName" ]
	then
	echo -e "\e[31mPlease provide the domain name\e[39m"
	exit
fi

if [ ! -d "$spAppRoot" ]
	then
	echo -e "\e[31mThe app name seems invalid as we didn't find its directory on your server\e[39m"
	exit 
fi

if [ -z "$appName" ]
	then
	echo -e "\e[31mPlease provide the app name\e[39m"
	exit
fi

if [ "$theAction" == "uninstall" ]; then
	sudo rm "$spSSLDir$appName-ssl.conf" &>/dev/null
	sudo service nginx-sp reload
	echo -e "\e[31mSSL has been removed. If you are seeing errors on your site, then please fix HTACCESS file and remove the rules that you added to force SSL\e[39m"
elif [ "$theAction" == "install" ]; then
	if [ -z "$domainType" ]
		then
		echo -e "\e[31mPlease provide the type of the domain (either main or sub)\e[39m"
		exit
	fi
	sudo service nginx-sp stop
	echo -e "\e[32mChecks passed, press enter to continue\e[39m"
	if [ "$domainType" == "main" ]; then
		thecommand="letsencrypt certonly --register-unsafely-without-email --agree-tos -d $domainName -d www.$domainName"
	elif [[ "$domainType" == "sub" ]]; then
		thecommand="letsencrypt certonly --register-unsafely-without-email --agree-tos -d $domainName"
	else
		echo -e "\e[31mDomain type not provided. Should be either main or sub\e[39m"
		exit
	fi
	output=$(eval $thecommand 2>&1) | xargs

	if [[ "$output" == *"too many requests"* ]]; then
		echo "Let's Encrypt SSL limit reached. Please wait for a few days before obtaining more SSLs for $domainName"
	elif [[ "$output" == *"Congratulations"* ]]; then
	
	if [ "$domainType" == "main" ]; then
		sudo echo "server {
	listen 443 ssl;
	listen [::]:443 ssl;
	server_name
	$domainName
	www.$domainName
	;

	ssl on;

	ssl_certificate /etc/letsencrypt/live/$domainName/fullchain.pem;
	ssl_certificate_key /etc/letsencrypt/live/$domainName/privkey.pem;

	root $spAppRoot/public;

	access_log /srv/users/serverpilot/log/$appName/dev_nginx.access.log main;
	error_log /srv/users/serverpilot/log/$appName/dev_nginx.error.log;

	proxy_set_header Host \$host;
	proxy_set_header X-Real-IP \$remote_addr;
	proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
	proxy_set_header X-Forwarded-SSL on;
	proxy_set_header X-Forwarded-Proto \$scheme;

	include /etc/nginx-sp/vhosts.d/$appName.d/*.nonssl_conf;
	include /etc/nginx-sp/vhosts.d/$appName.d/*.conf;
}" > "$spSSLDir$appName-ssl.conf"

	elif [ "$domainType" == "sub" ]; then
		sudo echo "server {
	listen 443 ssl;
	listen [::]:443 ssl;
	server_name
	$domainName
	;

	ssl on;

	ssl_certificate /etc/letsencrypt/live/$domainName/fullchain.pem;
	ssl_certificate_key /etc/letsencrypt/live/$domainName/privkey.pem;

	root $spAppRoot/public;

	access_log /srv/users/serverpilot/log/$appName/dev_nginx.access.log main;
	error_log /srv/users/serverpilot/log/$appName/dev_nginx.error.log;

	proxy_set_header Host \$host;
	proxy_set_header X-Real-IP \$remote_addr;
	proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
	proxy_set_header X-Forwarded-SSL on;
	proxy_set_header X-Forwarded-Proto \$scheme;

	include /etc/nginx-sp/vhosts.d/$appName.d/*.nonssl_conf;
	include /etc/nginx-sp/vhosts.d/$appName.d/*.conf;
}" > "$spSSLDir$appName-ssl.conf"
	fi
		echo -e "\e[32mSSL should have been installed for $domainName with auto-renewal (via cron)\e[39m"
		
	elif [[ "$output" == *"Failed authorization procedure."* ]]; then
		echo -e "\e[31m$domainName isn't being resolved to this server. Please check and update the DNS settings if necessary and try again when domain name points to this server\e[39m"
	elif [[ ! $output ]]; then
		# If no output, we will assume that a valid SSL already exists for this domain
		# so we will just add the vhost
		sudo echo "server {
	listen 443 ssl;
	listen [::]:443 ssl;
	server_name
	$domainName
	www.$domainName
	;

	ssl on;

	ssl_certificate /etc/letsencrypt/live/$domainName/fullchain.pem;
	ssl_certificate_key /etc/letsencrypt/live/$domainName/privkey.pem;

	root $spAppRoot/public;

	access_log /srv/users/serverpilot/log/$appName/dev_nginx.access.log main;
	error_log /srv/users/serverpilot/log/$appName/dev_nginx.error.log;

	proxy_set_header Host \$host;
	proxy_set_header X-Real-IP \$remote_addr;
	proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
	proxy_set_header X-Forwarded-SSL on;
	proxy_set_header X-Forwarded-Proto \$scheme;

	include /etc/nginx-sp/vhosts.d/$appName.d/*.nonssl_conf;
	include /etc/nginx-sp/vhosts.d/$appName.d/*.conf;
}" > "$spSSLDir$appName-ssl.conf"
	echo -e "\e[32mSSL should have been installed for $domainName with auto-renewal (via cron)\e[39m"
		grep "sudo service nginx-sp stop && yes | letsencrypt renew &>/dev/null && service nginx-sp start && service nginx-sp reload" /etc/crontab || sudo echo "@monthly sudo service nginx-sp stop && yes | letsencrypt renew &>/dev/null && service nginx-sp start && service nginx-sp reload" >> /etc/crontab
	else
		echo -e "\e[31mSomething unexpected occurred\e[39m"
	fi 
	sudo service nginx-sp start && sudo service nginx-sp reload
else
	echo -e "\e[31mTask cannot be identified. It should be either install or uninstall \e[39m"
fi
