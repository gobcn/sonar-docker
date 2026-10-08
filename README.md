# Sonar Poller Docker

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

See the [Sonar Poller documentation](github.com/sonarsoftwareinc/poller) for configuration and usage.

## License

BSD 3-Clause License.
