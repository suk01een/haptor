FROM haproxy:alpine
USER root

RUN apk add tor 
COPY ./haproxy.cfg /usr/local/etc/haproxy/haproxy.tpl
COPY ./entrypoint.sh /entrypoint.sh

ENTRYPOINT ["./entrypoint.sh"]
