FROM debian:jessie

RUN apt-get update
RUN apt-get install -y haproxy curl jq
#RUN apt-get install -y haproxy supervisor rsyslog curl
#RUN service rsyslog start
ADD haproxy-updater.sh /haproxy-updater.sh
ADD haproxy.cfg.tmpl /haproxy.cfg.tmpl

EXPOSE 80

CMD /haproxy-updater.sh
