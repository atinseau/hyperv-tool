proxy_address=prdproxyserv.groupe.lan:3128
proxy_user=<USER>
proxy_password=<PASSWORD>

echo -e " \e[32m Configuring transparent proxy for docker container \e[0m"
docker rm -f OGF-proxy-connector || true
docker run -d --name OGF-proxy-connector --restart unless-stopped --privileged -e HTTP_PROXY="${proxy_user}:${proxy_password}@${proxy_address}" \
        -e NO_PROXY=192.168.0.1/16,172.16.0.1/12,10.0.0.1/8 -e LISTEN_PORT=3129 -e IPTABLE_MARK=2515 \
        -e PROXY_PORTS=80,443 --net=host fengzhou/transparent-proxy
