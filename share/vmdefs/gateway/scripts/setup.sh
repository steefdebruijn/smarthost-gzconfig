#!/bin/bash

echo Setup basic IP routing and filtering...
touch /etc/ipf/ipnat.conf
routeadm -u -e ipv4-forwarding
svcadm enable route
svcadm enable ipfilter
sleep 2
ipnat -l

echo Creating directories...
mkdir -p /opt/local/etc/nginx/certs
mkdir -p /opt/local/etc/nginx/sites-available
mkdir -p /opt/local/etc/nginx/sites-enabled
mkdir -p /opt/local/www/acme

echo Creating nginx configuration...
mv /opt/local/etc/nginx/nginx.conf /opt/local/etc/nginx/nginx.conf.distr
cat << __eof > /opt/local/etc/nginx/nginx.conf
user   www  www;
worker_processes  1;

events {
    # After increasing this value You probably should increase limit
    # of file descriptors (for example in start_precmd in startup script)
    worker_connections  1024;
}


http {
    server_tokens off;
    more_clear_headers Server;
    more_set_headers 'Server: ankorboet';

    include       /opt/local/etc/nginx/mime.types;
    default_type  application/octet-stream;

    log_format  main  '\$remote_addr - \$remote_user [\$time_local] "\$request" '
                      '\$status \$body_bytes_sent "\$http_referer" '
                      '"\$http_user_agent" "\$http_x_forwarded_for"';

    access_log  /var/log/nginx/access.log  main;

    sendfile        on;
    #tcp_nopush     on;

    keepalive_timeout  65;

    #gzip  on;

# If we receive X-Forwarded-Proto, pass it through; otherwise, pass along the
# scheme used to connect to this server
map \$http_x_forwarded_proto \$proxy_x_forwarded_proto {
  default \$http_x_forwarded_proto;
  ''      \$scheme;
}
# If we receive X-Forwarded-Port, pass it through; otherwise, pass along the
# server port the client connected to
map \$http_x_forwarded_port \$proxy_x_forwarded_port {
  default \$http_x_forwarded_port;
  ''      \$server_port;
}
# If we receive Upgrade, set Connection to "upgrade"; otherwise, delete any
# Connection header that may have been passed to this server
map \$http_upgrade \$proxy_connection {
  default upgrade;
  '' close;
}
# Set appropriate X-Forwarded-Ssl header
map \$scheme \$proxy_x_forwarded_ssl {
  default off;
  https on;
}
gzip_types text/plain text/css application/javascript application/json application/x-javascript text/xml application/xml application/xml+rss text/javascript;
log_format vhost '\$host \$remote_addr - \$remote_user [\$time_local] '
                 '"\$request" \$status \$body_bytes_sent '
                 '"\$http_referer" "\$http_user_agent"';
access_log off;
# HTTP 1.1 support
proxy_http_version 1.1;
proxy_buffering off;
proxy_request_buffering off;
proxy_set_header Host \$http_host;
proxy_set_header Upgrade \$http_upgrade;
proxy_set_header Connection \$proxy_connection;
proxy_set_header X-Real-IP \$remote_addr;
proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
proxy_set_header X-Forwarded-Proto \$proxy_x_forwarded_proto;
proxy_set_header X-Forwarded-Ssl \$proxy_x_forwarded_ssl;
proxy_set_header X-Forwarded-Port \$proxy_x_forwarded_port;
proxy_connect_timeout       600;
proxy_send_timeout          600;
proxy_read_timeout          600;
send_timeout                600;
proxy_set_header Proxy "";

    include /opt/local/etc/nginx/sites-enabled/*.nginx;

}
__eof

svcadm enable nginx
