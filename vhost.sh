#!/bin/sh

docker_ip()
{
	DOCKER_IP_FIELD='{{.NetworkSettings.Gateway}}'
	/usr/bin/docker inspect -f "${DOCKER_IP_FIELD}" "$1"
}

docker_port()
{
	RANGE='{{range $k, $v := .NetworkSettings.Ports}}'
	INDEX='{{index (index $v 0) "HostPort"}} '
	END='{{end}}'
	DOCKER_PORT_FIELD="${RANGE}${INDEX}${END}"
	/usr/bin/docker inspect -f "${DOCKER_PORT_FIELD}" "$1" \
		| rev | cut -d' ' -f2 | rev # take the last port
}

docker_addr()
{
	IP=`eval docker_ip $1`
	PORT=`eval docker_port $1`
	echo "$IP:$PORT"
}

case $1 in
    register )
	/usr/bin/etcdctl set "/vhost/$2/`docker_addr $3`" '' ;;
    deregister )
	/usr/bin/etcdctl rm  "/vhost/$2/`docker_addr $3`" ;;
esac

