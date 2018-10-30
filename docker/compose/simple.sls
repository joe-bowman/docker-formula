{% from "docker/map.jinja" import docker with context %}

{% set compose_path = docker.get('compose', {}).get('simple').get('base_path', '/etc/docker/compose') %}

{% for service, config in docker.get('compose', {}).get('simple', {}).items() %}
docker_compose_directory_{{ service }}:
  file.directory:
    - name: {{ compose_path }}/{{ service }}
    - makedirs: True
    - user: docker
    - group: docker
    - recurse:
      - user
      - group

  {% if config.get('compose_file', False) %}
docker_compose_managed_compose_file_{{ service }}:
  file.managed:
    - name: {{ compose_path }}/{{ service }}/docker-compose.yml
    - source: {{ config.get('compose_path') }}
    - user: docker
    - group: docker

  {% elif config.get('compose', False) %}
docker_compose_managed_compose_file_{{ service }}:
  file.serialize:
    - name: {{ compose_path }}/{{ service }}/docker-compose.yml
    - dataset:
        version: '3.4'
        volumes: {{ config.get('compose').get('volumes', {}) }}
        services: {{ config.get('compose').get('services', {}) }}
    - user: docker
    - group: docker

  {% endif %}

  {% for dst, src in config.get('copy_env_files', {}).items() %}
docker_compose_copy_env_file_{{ service }}_{{ dst|replace('/', '_') }}:
  file.managed:
    - name: {{ compose_path }}/{{ service }}/{{ dst }}
    - src: {{ src }}
    - user: docker
    - group: docker
  {% endfor %}

  {% if config.get('env', False) %}
docker_compose_manage_env_file_{{ service }}:
  file.managed:
    - name: {{ compose_path }}/{{ service }}/.env
    - source: salt://docker/files/.env.jinja
    - template: jinja
    - context:
        config: {{ config.get('env') }}
    - user: docker
    - group: docker
  {% endif %}

  {% if config.get('service', False) %}
docker_compose_systemd_{{ service }}:
  file.managed:
    - name: /etc/systemd/system/docker-{{ service }}.service
    - source: salt://docker/files/compose_service_file.jinja
    - template: jinja
    - context:
        working_dir: {{ compose_path }}/{{ service }}
        name: {{ service }}
        env_vars: {{ config.get('env_vars', {}) }}

docker_compose_enable_{{ service }}:
  service.enabled:
    - name: docker-{{ service }}

docker_compose_running_{{ service }}:
  service.running:
    - name: docker-{{ service }}
  {% endif %}

{% endfor %}
