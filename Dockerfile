# Sonar Poller image for Broadband Communications North (BCN)
FROM ubuntu:noble

RUN apt-get -yq update && \
apt-get install -y nginx php8.3-cli php8.3-xml php8.3-common php8.3-gmp php8.3-dev php8.3-sqlite3 php8.3-zip php8.3-fpm php8.3-mbstring libev-dev composer openssl php-pear snmp supervisor curl


RUN pecl channel-update pecl.php.net && \
printf "\n" | pecl install ev && \
grep -qxF 'extension=ev.so' /etc/php/8.3/cli/php.ini || echo "extension=ev.so" >> /etc/php/8.3/cli/php.ini && \
grep -qxF 'extension=ev.so' /etc/php/8.3/fpm/php.ini || echo "extension=ev.so" >> /etc/php/8.3/fpm/php.ini

## Install the latest fping
RUN apt-get install -y fping && \
setcap cap_net_raw+ep /usr/bin/fping && \
## Maintain compatability with legacy version so code stays the same for both
ln -s /usr/bin/fping /usr/local/sbin/fping

# Enable garbage collection in PHP directly
RUN sed -i 's/^session.gc_probability = 0/session.gc_probability = 1/' /etc/php/8.3/fpm/php.ini \
&& sed -i 's/^session.gc_divisor = 100/session.gc_divisor = 100/' /etc/php/8.3/fpm/php.ini \
&& sed -i 's/^session.gc_maxlifetime = 1440/session.gc_maxlifetime = 1440/' /etc/php/8.3/fpm/php.ini

# clone and setup poller
COPY --chown=www-data:www-data sonar_poller /usr/share/sonar_poller

# install NGINX and self signed cert
RUN cp /usr/share/sonar_poller/ssl/self-signed.conf /etc/nginx/snippets/ && \
cp /usr/share/sonar_poller/ssl/default /etc/nginx/sites-available/

# Write version supplied by the build
ARG SONAR_POLLER_VERSION
RUN echo "$SONAR_POLLER_VERSION" > /usr/share/sonar_poller/version

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
