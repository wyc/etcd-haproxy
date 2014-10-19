#!/bin/sh

DOCKER_INTERFACE="http://172.17.42.1:4001"

etcd_ls()
{
        curl -s -L "${DOCKER_INTERFACE}/v2/keys$1" \
                | jq -r .node.nodes[].key 2>/dev/null
}

etcd_watch()
{
        curl -s -L "${DOCKER_INTERFACE}/v2/keys$1?wait=true&recursive=true" \
                | jq .
}

regen_config()
{
        ACL=""
        USE_BACKEND=""
        BACKEND=""

        VHOSTS=`etcd_ls /vhost`
        echo "[Reload VHOSTS]"
        for vh in ${VHOSTS}; do 
                # e.g., a sub-domain such as foo.bar.com
                VHOST_NAME=`basename ${vh}`
                # e.g., foo_bar_com
                FIXED_VHOST_NAME=`echo ${VHOST_NAME} | tr '.' '_'`

                # Define the ACL as requests with VHOST_NAME as the target host
                ACL="${ACL}\
        acl host_${FIXED_VHOST_NAME} hdr(host) -i ${VHOST_NAME}\n"

                # Route the ACL to the respective backend
                USE_BACKEND="${USE_BACKEND}\
        use_backend ${FIXED_VHOST_NAME}_backend if host_${FIXED_VHOST_NAME}\n"

                # Define the backend
                BACKEND="${BACKEND}\
backend ${FIXED_VHOST_NAME}_backend\n"

                # Add hosts to the backend such as 127.0.0.0:3000
                echo "${VHOST_NAME} hosts:"
                IDX=0
                HOSTS=`etcd_ls $vh`
                for h in ${HOSTS}; do
                        ADDR=`basename ${h}`
                        echo "  - ${ADDR}"
                        BACKEND="${BACKEND}\
        server server_${FIXED_VHOST_NAME}${IDX} ${ADDR} maxconn 30 check inter 10000\n"
                        IDX=`expr ${IDX} + 1`
                done
                BACKEND="${BACKEND}\n\n"
        done

	mkdir -p /etc/haproxy
        # Replace three things in the template with variables
        sed -e "s/{{acl}}/${ACL}/" \
            -e "s/{{use_backend}}/${USE_BACKEND}/" \
            -e "s/{{backend}}/${BACKEND}/" \
            haproxy.cfg.tmpl > /etc/haproxy/haproxy.cfg

        echo ""
	cat /etc/haproxy/haproxy.cfg
}

reload_haproxy()
{
	pkill -9 -e ^haproxy$
	service haproxy restart
}

watch_loop()
{
        while true; do
                regen_config
                reload_haproxy
                etcd_watch /vhost
        done
}

watch_loop
