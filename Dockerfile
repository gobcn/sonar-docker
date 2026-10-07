# Sonar Poller image for Broadband Communications North (BCN)
FROM ubuntu:noble
RUN apt-get -yq update && \
apt-get -yq --no-install-recommends install software-properties-common
RUN apt-get -y update && \
apt-get install -y nginx php8.3-cli php8.3-xml php8.3-common php8.3-gmp php8.3-dev php8.3-sqlite3 php8.3-zip php8.3-fpm php8.3-mbstring libev-dev composer openssl git php-pear snmp supervisor memmon
RUN pecl channel-update pecl.php.net && \
print "\n" | pecl install ev && \
grep -qxF 'extension=ev.so' /etc/php/8.3/cli/php.ini || echo "extension=ev.so" >> /etc/php/8.3/cli/php.ini && \
grep -qxF 'extension=ev.so' /etc/php/8.3/fpm/php.ini || echo "extension=ev.so" >> /etc/php/8.3/fpm/php.ini
## Install the latest fping
RUN apt-get install -y fping && \
setcap cap_net_raw+ep /usr/bin/fping && \
## Maintain compatability with legacy version so code stays the same for both
ln -s /usr/bin/fping /usr/local/sbin/fping
### Handled outside of container, on host / by compose. Preserved for debugging.
## Setup sysctl for better monitoring performance
#grep -qxF 'net.core.somaxconn=4096' /etc/sysctl.conf || echo "net.core.somaxconn=4096" >> /etc/sysctl.conf
#grep -qxF 'net.ipv4.icmp_ratelimit=0' /etc/sysctl.conf || echo "net.ipv4.icmp_ratelimit=0" >> /etc/sysctl.conf
#grep -qxF 'net.ipv4.icmp_msgs_per_sec=100000' /etc/sysctl.conf || echo "net.ipv4.icmp_msgs_per_sec=100000" >> /etc/sysctl.conf
#grep -qxF 'net.ipv4.icmp_msgs_burst=5000' /etc/sysctl.conf || echo "net.ipv4.icmp_msgs_burst=5000" >> /etc/sysctl.conf
#grep -qxF 'fs.file-max = 500000' /etc/sysctl.conf || echo "fs.file-max = 500000" >> /etc/sysctl.conf
#/sbin/sysctl -p
#grep -qxF 'DefaultLimitNOFILE=65535' /etc/systemd/system.conf || echo "DefaultLimitNOFILE=65535" >> /etc/systemd/system.conf
#grep -qxF '* hard nofile 65535' /etc/security/limits.d/custom.conf || echo "* hard nofile 65535" >> /etc/security/limits.d/custom.conf
#grep -qxF '* soft nofile 65535' /etc/security/limits.d/custom.conf || echo "* soft nofile 65535" >> /etc/security/limits.d/custom.conf
RUN sed -i 's/^session.gc_probability = 0/session.gc_probability = 1/' /etc/php/8.3/fpm/php.ini \
&& sed -i 's/^session.gc_divisor = 100/session.gc_divisor = 100/' /etc/php/8.3/fpm/php.ini \
&& sed -i 's/^session.gc_maxlifetime = 1440/session.gc_maxlifetime = 1440/' /etc/php/8.3/fpm/php.ini
# clone and setup poller
RUN cd /usr/share && \
rm -rf sonar_poller

COPY sonar_poller /usr/share/sonar_poller

# set permissions
RUN chown -R www-data:www-data /usr/share/sonar_poller
# install NGINX and self signed cert
RUN cp /usr/share/sonar_poller/ssl/self-signed.conf /etc/nginx/snippets/ && \
cp /usr/share/sonar_poller/ssl/default /etc/nginx/sites-available/
## Write version and prevent potential dubious ownership error
RUN git config --global --add safe.directory /usr/share/sonar_poller && \
cd /usr/share/sonar_poller && \
git describe --tags > version
## Install vendor libraries needed for poller
RUN mkdir /var/www/.composer && \
chown www-data:www-data /var/www/.composer && \
chown -R www-data:www-data /var/lib/nginx
USER www-data
RUN cd /usr/share/sonar_poller && composer install
USER root
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf
RUN mkdir -p /var/run/php && \
mkdir -p /var/lib/php-fpm
# perform a (very basic) health check
HEALTHCHECK --interval=30s --timeout=3s \
  CMD curl -fks https://localhost || exit 1
CMD ["/usr/bin/supervisord"]
# expose NGINX
EXPOSE 443/tcp
