{% from "docker/map.jinja" import docker with context %}

{% if "pkgrepo" in docker.kernel %}
{{ grains["oscodename"] }}-backports-repo:
  pkgrepo.managed:
    {% for key, value in docker.kernel.pkgrepo.items() %}
    - {{ key }}: {{ value }}
    {% endfor %}
    - require:
      - pkg: docker package dependencies
    - onlyif: dpkg --compare-versions {{ grains["kernelrelease"] }} lt 3.8
{% endif %}

{% if "pkg"  in docker.kernel %}
docker-dependencies-kernel:
  pkg.installed:
    {% for key, value in docker.kernel.pkg.items() %}
    - {{ key }}: {{ value }}
    {% endfor %}
    - require_in:
      - pkg: docker package
    - onlyif: dpkg --compare-versions {{ grains["kernelrelease"] }} lt 3.8
{% endif %}
