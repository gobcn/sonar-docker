# Sonar Poller Docker Image

Docker image for running [Sonar Poller](github.com/sonarsoftwareinc/poller).

## Included

- Ubuntu 24.04
- PHP 8.3 / PHP-FPM
- NGINX
- Supervisor
- SNMP
- fping
- Sonar Poller

Supervisor manages NGINX, PHP-FPM, and the poller process.

## Docker configuration
An [example docker compose file](docker-compose.yaml) is provided. 

The example compose uses external volumes, to create your volume run the following command: 

```docker volume create sonar-poller-customer```.

## Poller configuration

See the [Sonar Poller documentation](https://github.com/sonarsoftwareinc/poller) for configuration and usage.

## Host configuration
### Set sysctl.conf options
```
grep -qxF 'net.core.somaxconn=4096' /etc/sysctl.conf || echo "net.core.somaxconn=4096" >> /etc/sysctl.conf
grep -qxF 'net.ipv4.icmp_ratelimit=0' /etc/sysctl.conf || echo "net.ipv4.icmp_ratelimit=0" >> /etc/sysctl.conf
grep -qxF 'net.ipv4.icmp_msgs_per_sec=100000' /etc/sysctl.conf || echo "net.ipv4.icmp_msgs_per_sec=100000" >> /etc/sysctl.conf
grep -qxF 'net.ipv4.icmp_msgs_burst=5000' /etc/sysctl.conf || echo "net.ipv4.icmp_msgs_burst=5000" >> /etc/sysctl.conf
grep -qxF 'fs.file-max = 500000' /etc/sysctl.conf || echo "fs.file-max = 500000" >> /etc/sysctl.conf
/sbin/sysctl -p
```
### Set limits options
```
grep -qxF 'DefaultLimitNOFILE=65535' /etc/systemd/system.conf || echo "DefaultLimitNOFILE=65535" >> /etc/systemd/system.conf
grep -qxF '* hard nofile 65535' /etc/security/limits.d/custom.conf || echo "* hard nofile 65535" >> /etc/security/limits.d/custom.conf
grep -qxF '* soft nofile 65535' /etc/security/limits.d/custom.conf || echo "* soft nofile 65535" >> /etc/security/limits.d/custom.conf
```
## License

BSD 3-Clause License.
