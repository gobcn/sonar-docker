# PIE (PHP Installer for Extensions), pinned so Dependabot can track updates
FROM ghcr.io/php/pie:1.4.5-bin@sha256:9d3e6d9dafa5ae8cf034489260e206a5aa1b488b29c0ddaea9149826d9e32f52 AS pie

# Sonar Poller image for Broadband Communications North (BCN)
FROM ubuntu:noble@sha256:534baea6a22c03a63003dbc8dbe78fe34bc0d7e595d9a9dc9834884ff530eb55

RUN apt-get -yq update && \
apt-get install -y nginx php8.3-cli php8.3-xml php8.3-common php8.3-gmp php8.3-dev php8.3-sqlite3 php8.3-zip php8.3-fpm php8.3-mbstring libev-dev composer openssl php-pear snmp supervisor curl logrotate

# Fail a RUN if any command in a pipe fails (hadolint DL4006)
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Install the ev extension with PIE; PIE enables it for all PHP SAPIs via phpenmod
COPY --from=pie /pie /usr/local/bin/pie
RUN pie install osmanov/pecl-ev

## Install the latest fping
RUN apt-get install -y fping && \
setcap cap_net_raw+ep /usr/bin/fping && \
## Maintain compatability with legacy version so code stays the same for both
ln -s /usr/bin/fping /usr/local/sbin/fping

# Enable garbage collection in PHP directly
RUN sed -i 's/^session.gc_probability = 0/session.gc_probability = 1/' /etc/php/8.3/fpm/php.ini \
&& sed -i 's/^session.gc_divisor = 100/session.gc_divisor = 100/' /etc/php/8.3/fpm/php.ini \
&& sed -i 's/^session.gc_maxlifetime = 1440/session.gc_maxlifetime = 1440/' /etc/php/8.3/fpm/php.ini \
# PHP-FPM (www-data) must be able to list the session dir for GC to clean
&& install -d -o www-data -g www-data -m 1733 /var/lib/php/sessions

# clone and setup poller
COPY --chown=www-data:www-data sonar_poller /usr/share/sonar_poller

# install NGINX and self signed cert
RUN cp /usr/share/sonar_poller/ssl/self-signed.conf /etc/nginx/snippets/ && \
cp /usr/share/sonar_poller/ssl/default /etc/nginx/sites-available/

# Send nginx and php-fpm logs to the container's stdout/stderr instead of files
RUN ln -sf /dev/stdout /var/log/nginx/access.log && \
ln -sf /dev/stderr /var/log/nginx/error.log && \
sed -i 's|^error_log = .*|error_log = /proc/self/fd/2|' /etc/php/8.3/fpm/php-fpm.conf

# Rotate the poller's own log files using upstream's config (run hourly by supervisord).
# Swap "create" for "copytruncate" so the poller's long-lived log handle isn't
# left writing to a rotated-away file; fail the build if the swap didn't apply.
RUN cp /usr/share/sonar_poller/config/sonar_poller_logs /etc/logrotate.d/ && \
sed -i 's/^\([[:space:]]*\)create\([[:space:]].*\)\?$/\1copytruncate/' /etc/logrotate.d/sonar_poller_logs && \
grep -q '^[[:space:]]*copytruncate$' /etc/logrotate.d/sonar_poller_logs

# Write version supplied by the build
ARG SONAR_POLLER_VERSION
RUN echo "$SONAR_POLLER_VERSION" > /usr/share/sonar_poller/version

## Install vendor libraries needed for poller
RUN mkdir /var/www/.composer && \
chown www-data:www-data /var/www/.composer && \
chown -R www-data:www-data /var/lib/nginx
USER www-data
RUN composer install --working-dir=/usr/share/sonar_poller
USER root
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf
RUN mkdir -p /var/run/php && \
mkdir -p /var/lib/php-fpm

# perform a (very basic) health check
HEALTHCHECK --interval=30s --timeout=3s \
  CMD ["/bin/sh", "-c", "curl -fks https://localhost || exit 1"]

  
CMD ["/usr/bin/supervisord"]
 
# expose NGINX
EXPOSE 443/tcp
