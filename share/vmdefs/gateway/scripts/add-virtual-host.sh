#!/bin/bash
echo
echo Configuring Virtual Host $1 on $2:$3
echo

echo Enabling NAT/IP forwarding...
echo FIXME: avoid duplicate entries
echo "    map net0 ${2}/32 -> 0/32" >> /etc/ipf/ipnat.conf
svcadm refresh ipfilter
sleep 2
ipnat -l

if test ! -f /opt/local/etc/nginx/certs/${1}.dhparam.pem; then
	echo Generating DH Params, grab a lunch...
	openssl dhparam 4096 > /opt/local/etc/nginx/certs/${1}.dhparam.pem
fi

if test ! -f /opt/local/etc/nginx/certs/${1}.account.key; then
	echo Generating account key...
	openssl genrsa 4096 > /opt/local/etc/nginx/certs/${1}.account.key
fi

if test ! -f /opt/local/etc/nginx/certs/${1}.domain.key; then
	echo Generating domain key...
	openssl genrsa 4096 > /opt/local/etc/nginx/certs/${1}.domain.key
fi

if test ! -f /opt/local/etc/nginx/certs/${1}.domain.csr; then
	echo Generating domain csr...
	openssl req -new -sha256 -key /opt/local/etc/nginx/certs/${1}.domain.key -subj "/CN=${1}" > /opt/local/etc/nginx/certs/${1}.domain.csr
fi

cat << __eof > /opt/local/etc/nginx/sites-available/${1}.nginx
upstream ${1} {
	keepalive 100;
	server ${2}:${3};
}
server {
	server_name ${1};
	listen 80 ;
	client_max_body_size 0;
	access_log /var/log/nginx/${1}.log;
	error_log  /var/log/nginx/${1}.err;
	return 301 https://\$host\$request_uri;
}
server {
	server_name ${1};
	listen 443 ssl http2 ;
	client_max_body_size 0;
	access_log /var/log/nginx/${1}.log;
	error_log  /var/log/nginx/${1}.err;
	ssl_protocols TLSv1.2;
        ssl_ciphers HIGH:!aNULL:!MD5;
	ssl_prefer_server_ciphers on;
	ssl_session_timeout 5m;
	ssl_session_cache shared:SSL:50m;
#        ssl_session_cache shared:vygd:2m;
#        ssl_ecdh_curve secp521r1;
	ssl_session_tickets off;
	ssl_dhparam         /opt/local/etc/nginx/certs/${1}.dhparam.pem;
	ssl_certificate_key /opt/local/etc/nginx/certs/${1}.domain.key;
	ssl_certificate     /opt/local/etc/nginx/certs/${1}.chain.pem;
	add_header Strict-Transport-Security "max-age=31536000";
	location ^~ /.well-known/acme-challenge/ {
		alias /opt/local/www/acme/;
		try_files \$uri =404;
		break;
	}
	location / {
		proxy_pass http://${1};
	}
}
__eof

ln -s /opt/local/etc/nginx/sites-available/${1}.nginx /opt/local/etc/nginx/sites-enabled/${1}.nginx

/root/scripts/domain-renew.sh ${1}
