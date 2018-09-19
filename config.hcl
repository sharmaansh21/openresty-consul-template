consul {
    address = "consul:8500"
}

template {
    source = "/opt/app/nginx/conf/nginx.conf.ctmpl"
    command = "/opt/app/nginx/sbin/nginx -s reload"
}
