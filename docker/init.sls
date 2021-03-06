{% from "docker/map.jinja" import docker with context %}

docker_package_dependencies:
  pkg.installed:
    - pkgs:
{%- if grains['os_family']|lower == 'debian' %}
      - apt-transport-https
      - python-apt
{%- endif %}
      - iptables
      - ca-certificates
{% if docker.kernel.pkgs != [] %}
      {{ docker.kernel.pkgs|yaml|indent(6) }}
{% endif %}
{% if docker.install_docker_py %}
      - {{ docker.python_pip_package }}
{% endif %}
    - unless: test "`uname`" = "Darwin"

{% if docker.install_docker_py %}
  pip.installed:
    - name: {{ docker.get('python_package', 'docker-py') }} {{ docker.get('pip_version', '') }}
    - reload_modules: True
{% endif %}

{% if docker.kernel is defined %}
include:
  - .kernel
{% endif %}

{% set repo_state = 'absent' %}
{% if docker.use_upstream_repo %}
  {% set repo_state = 'managed' %}
{% endif %}

{%- if grains['os_family']|lower == 'debian' %}
  {%- if grains["oscodename"]|lower == 'jessie' and grains['cpuarch'] == 'aarch64' %}
  ## jessie on aarch64 cpus needs to use jessie-backports repo.
  {% set docker_pkg = [{'name': 'docker.io'}, {'fromrepo': docker.kernel.pkg.fromrepo}] %}
docker_package_repository:
  pkgrepo.{{ repo_state }}:
    - name: deb http://http.debian.net/debian jessie-backports main
  {%- else %}
    {%- set use_old_repo = docker.version is defined and salt['pkg.version_cmp'](docker.version|replace('*' ,''), '1.5.1') < 0 %}

    {%- if use_old_repo %}
    {% set docker_pkg = [{'name': 'lxc-docker'}] %}
docker_package_repository:
  pkgrepo.{{ repo_state }}:
    - name: deb https://get.docker.com/ubuntu docker main
    - humanname: Old docker_package_repository
    - keyid: d8576a8ba88d21e9
    - keyserver: hkp://p80.pool.sks-keyservers.net:80
    {%- else %}

purge old packages:
  pkgrepo.absent:
    - name: deb https://get.docker.com/ubuntu docker main
  pkg.purged:
    - pkgs:
      - lxc-docker*
      - docker.io*
    - require_in:
      - pkgrepo: docker_package_repository

    {%- if (docker.version is defined and salt['pkg.version_cmp'](docker.version|replace('*' ,''), '1.14') < 0)
        or grains['oscodename']|lower in ('precise', 'utopic', 'wily') %} ## use docker project repo for old versions (version <= 1.13) or unsupported EOL os versions.
        {% set docker_pkg = [{'name': 'docker-engine'}] %}
docker_package_repository:
  pkgrepo.{{ repo_state }}:
    - name: deb https://apt.dockerproject.org/repo {{ grains["os"]|lower }}-{{ salt['grains.get']('oscodename') }} main
    - humanname: {{ grains["os"] }} {{ grains["oscodename"]|capitalize }} docker_package_repository
    - keyid: 58118E89F3A912897C070ADBF76221572C52609D
    - keyserver: hkp://p80.pool.sks-keyservers.net:80
    {%- elif grains['os']|lower == 'ubuntu' %}
    {% set docker_pkg = [{'name': 'docker-ce'}] %}
docker_package_repository:
  pkgrepo.{{ repo_state }}:
    - name: deb https://download.docker.com/linux/ubuntu {{ salt['grains.get']('oscodename') }} {{ docker.get('testing', 'stable') }}
    - humanname: {{ grains["os"] }} {{ grains["oscodename"]|capitalize }} docker_package_repository
    - key_url: https://download.docker.com/linux/ubuntu/gpg
    {%- else %}
    {% set docker_pkg = [{'name': 'docker-ce'}] %}
docker_package_repository:
  pkgrepo.{{ repo_state }}:
    - name: deb https://download.docker.com/linux/debian {{ salt['grains.get']('oscodename') }} {{ docker.get('testing', 'stable') }}
    - humanname: {{ grains["os"] }} {{ grains["oscodename"]|capitalize }} docker_package_repository
    - key_url: https://download.docker.com/linux/debian/gpg
    {%- endif %}
    {%- endif %}
    - file: /etc/apt/sources.list.d/docker.list
    - refresh_db: True
  {%- endif %}

{%- elif grains['os_family']|lower == 'redhat' and grains['os']|lower != 'amazon' %}

  {% if grains['os']|lower == 'suse' %}
    {% set yumrepo =  'opensuse' %}
  {% elif grains['os']|lower == 'redhat' %}
    {% set yumrepo =  'centos' %}
  {% else %}
    {% set yumrepo = grains['os']|lower %}
  {% endif %}

  {%- if docker.version is defined and salt['pkg.version_cmp'](docker.version|replace('*' ,''), '1.14') < 0 %}
  {% set docker_pkg = [{'name': 'docker-engine'}] %}
docker_package_repository:
  pkgrepo.{{ repo_state }}:
    - name: docker
    - baseurl: https://yum.dockerproject.org/repo/main/{{ yumrepo }}/$releasever/
    - gpgcheck: 1
    - gpgkey: https://yum.dockerproject.org/gpg
    - require_in:
      - pkg: docker package
    - require:
      - pkg: docker_package_dependencies
  {%- else %}
  {% set docker_pkg = [{'name': 'docker-ce'}] %}
docker_package_repository:
  pkgrepo.{{ repo_state }}:
    - name: docker
    - baseurl: https://download.docker.com/linux/{{ yumrepo }}/$releasever/$basearch/{{ docker.get('testing', 'stable') }}
    - gpgcheck: 1
    - gpgkey: https://download.docker.com/linux/{{ yumrepo }}/gpg
    - require_in:
      - pkg: docker package
    - require:
      - pkg: docker_package_dependencies
  {%- endif %}
{%- endif %}

docker package:
  pkg.installed:
    {{ docker_pkg|default([{'name': 'docker'}])|yaml(False) }}
    - refresh: {{ docker.refresh_repo }}
    - require:
      - pkg: docker_package_dependencies
      {%- if grains['os']|lower != 'amazon' %}
      - pkgrepo: docker_package_repository
      {%- endif %}
    - require_in:
      - file: docker-config
    - allow_updates: {{ docker.pkg.allow_updates }}
      {% if docker.pkg.version %}
    - version: {{ docker.pkg.version }}
      {% elif "version" in docker %}
    - version: {{ docker.version }}
      {% endif %}
      {% if docker.pkg.hold %}
    - hold: {{ docker.pkg.hold }}
      {% endif %}

docker-config:
  file.managed:
    - name: {{ docker.configfile }}
    - source: salt://docker/files/config
    - template: jinja
    - mode: 644
    - user: root

docker_config_json:
  file.serialize:
    - name: /root/.docker/config.json
    - dataset_pillar: docker:config_json
    - formatter: json
    - mode: 644
    - user: root
    - makedirs: True

docker_daemon_json:
  file.serialize:
    - name: /etc/docker/daemon.json
    - dataset_pillar: docker:daemon_json
    - formatter: json
    - onlyif: {{ pillar.get('docker').get('daemon_json', False) != False }}
    - mode: 644
    - user: root
    - makedirs: True

docker-service:
  service.running:
    - name: docker
    - enable: True
    - restarted: True
    - watch:
      - file: /etc/default/docker
      - pkg: docker package
    {% if "process_signature" in docker %}
    - sig: {{ docker.process_signature }}
    {% endif %}
    - file: docker_daemon_json
    - file: docker_config_json
