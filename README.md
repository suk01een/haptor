# Description
haptor is an IP randomizer proxy. The original motivation is to work around requests per time unit based IP blocking. It is nothing more that a backend of Tor listeners hiding behind a reverse proxy frontend. Tor was chosen as the backend for the simple reason that it is a free proxy service provider. Because the frontend is designed to receive a high request load by nature of the problem it is solving, the choice went in favour of [Haproxy](https://github.com/haproxy/haproxy) for its high performance [compared to other open source proxy services](https://github.com/NickMRamirez/Proxy-Benchmarks).


# Disclaimers
Tor is usually used to anonymize your network transactions, but this project only uses it to access freely available proxy servers, and does not try in any way to anonymize your traffic.
Assuming your DNS config uses UDP for example, the DNS traffic will not be routed through the proxy.


# Limits
The proxy server only supports SOCKS protocol.


# Configuration Files
Tor looks by default for a configuration file at **/etc/tor/torrc**. The file is absent if not mounted by the user, a default configuration will be generated by the entrypoint script, and the full config will be printed on run (unless ran as deamon).
If you want to use a custom tor config file, you can mount it at **/etc/tor/torrc**. This will skip the dynamic backend config generation.
In case you need to include a bit of the torrc but still dynamically generate the backend configuration, you can mount it as a configuration prefix at **/etc/tor/torrc.pfx**.

The base Haproxy configuration can be found at **docker/haproxy.tpl**. The backend servers list will be dynamically added to the config by the entrypoint script, and the full config will be printed on run (unless ran as deamon).
If you want to use a custom haproxy config file, you can mount it at **/usr/local/etc/haproxy/haproxy.cfg**. This will skip the dynamic backend generation.


# Usage
The docker-compose usees two environment variables :
**LISTEN_PORT**: represents to frontend port, you will use to connect to haptor. Default is 8050.
**LISTENERS** : represents the number of tor listeners to spawn. Default is 10.
**BALANCING_ALGORITHM**: represents the balancing algorithm to be used by haproxy. Default is roundrobin.
*Others choices are "leastconn" and "source". The latter, depending on the context in which haptor is used, will most likely not randomize your IP address; actually quite the opposite.*
*Link below for more details.*
*https://www.digitalocean.com/community/tutorials/an-introduction-to-haproxy-and-load-balancing-concepts#load-balancing-algorithms*



## Default usage
```docker-compose up```


## Using custom LISTEN_PORT and LISTENERS
```LISTEN_PORT=8080 LISTENERS=25 docker-compose up```

```docker-compose run -e LISTEN_PORT=8080 -e LISTENERS=25 haptor```


## Using custom configs
```docker-compose run -v <your_torrc_absolute_path>:/etc/tor/torrc -v <your_haproxy_conf_absolute_path>:/usr/local/etc/haproxy/haproxy.cfg  haptor```
*Please note the importance of specifying the absolute path when using mounted volumes with docker. Failing to do so results in failure to mount volumes. This issue is docker related.*


## Cleaning up
```docker-compose down```


## test.sh
The test.sh script is at your disposition to check that the traffic is split between different routes.
The test.sh script basically makes 10 concurrent requests to https://ipinfo.io/ip and print the results. If everything works as expected, you should see different IP addresses printed.
