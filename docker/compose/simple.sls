{% from "docker/map.jinja" import docker with context %}

{% set compose_path = docker.get('compose', {}).get('simple').get('base_path', '/etc/docker/compose') %}

{% for service, config in docker.get('compose', {}).get('simple') %}
docker_compose_directory_{{ service }}:
  file.directory:
    - name: {{ compose_path }}/{{ service }}
    - make_dirs: True
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

  {% elseif config.get('compose', False) %}
docker_compose_managed_compose_file_{{ service }}:
  file.serialize:
    - name: {{ compose_path }}/{{ service }}/docker-compose.yml
    - dataset:
        version: '3.4'
        services: {{ config.get('compose') }}
    - user: docker
    - group: docker

  {% endif %}

  {% if config.get('service', False) %}
docker_compose_systemd_service:
  file.managed:
    - name: /etc/systemd/system/docker-{{ service }}.service
    - source: salt://docker/files/compose_service_file.jinja
    - template: jinja
    - context:
      - working_dir: {{ compose_path }}/{{ service }}
      - name: {{ service }}

docker_compose_enable_service:
  service.enabled:
    - name: docker-{{ service }}

  service.running:
    - name: docker-{{ service }}
  {% endif %}

{% endfor %}
