# Sonar Poller image for Broadband Communications North (BCN)

# PIE (PHP Installer for Extensions), pinned so Dependabot can track updates
FROM ghcr.io/php/pie:1.4.5-bin@sha256:9d3e6d9dafa5ae8cf034489260e206a5aa1b488b29c0ddaea9149826d9e32f52 AS pie
# Ubuntu Noble (Latest tag)
FROM ubuntu:noble@sha256:68ee22004a9109b44973313b02ff7b1de250f1de0f5ecb628d73f579aaff33ac

# Fail a RUN if any command in a pipe fails (hadolint DL4006)
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Build-time only; keeps apt from prompting without baking it into the runtime env
ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update -yq && \
    apt-get install -yq \
        composer \
        curl \
        fping \
        libcap2-bin \
        libev-dev \
        logrotate \
        nginx \
        openssl \
        php8.3-cli \
        php8.3-common \
        php8.3-dev \
        php8.3-fpm \
        php8.3-gmp \
        php8.3-mbstring \
        php8.3-sqlite3 \
        php8.3-xml \
        php8.3-zip \
        snmp \
        supervisor && \
    # Let fping send ICMP without root
    setcap cap_net_raw+ep /usr/bin/fping && \
    # Maintain compatibility with legacy path so code stays the same for both
    ln -s /usr/bin/fping /usr/local/sbin/fping && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Install the ev extension with PIE; PIE enables it for all PHP SAPIs via phpenmod
COPY --from=pie /pie /usr/local/bin/pie
RUN pie install osmanov/pecl-ev

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
