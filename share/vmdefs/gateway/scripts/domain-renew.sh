#!/bin/bash
if test ! -f ${1}.chain.pem || echo $1 | grep local > /dev/null; then
    openssl x509 -req -days 365 \
	    -in /opt/local/etc/nginx/certs/${1}.domain.csr \
	    -signkey /opt/local/etc/nginx/certs/${1}.domain.key \
	    -out /opt/local/etc/nginx/certs/${1}.domain.crt
    cp /opt/local/etc/nginx/certs/${1}.domain.crt \
       /opt/local/etc/nginx/certs/${1}.chain.pem
else
    acme_tiny --account-key /opt/local/etc/nginx/certs/${1}.account.key \
	      --csr /opt/local/etc/nginx/certs/${1}.domain.csr \
	      --acme-dir /opt/local/www/acme \
	      > /opt/local/etc/nginx/certs/${1}.domain.crt
    curl -s 'https://letsencrypt.org/certs/lets-encrypt-x3-cross-signed.pem' \
     	 > /opt/local/etc/nginx/certs/letsencrypt.pem
    cat /opt/local/etc/nginx/certs/${1}.domain.crt \
	/opt/local/etc/nginx/certs/letsencrypt.pem \
	> /opt/local/etc/nginx/certs/${1}.chain.pem
fi
nginx -s reload
