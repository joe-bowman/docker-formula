{%- from 'cosmos/map.jinja' import cosmos with context %}

ecr_helper_prerequisites:
  pkg.installed:
    - name: git

  pip.installed:
    - name: docker

clone_ecr_helper:
  git.latest:
    - name: https://github.com/awslabs/amazon-ecr-credential-helper.git
    - target: /opt/ecr-helper
    - branch: master
    - require:
      - pkg: ecr_helper_prerequisites
      - pip: ecr_helper_prerequisites

build_ecr_helper:
  cmd.run:
    - name: make docker
    - cwd: /opt/ecr-helper
    - unless: test -x /opt/ecr-helper/bin/local/docker-credential-ecr-login
    - require:
      - git: clone_ecr_helper

permissions_ecr_helper:
  cmd.run:
    - name: chmod 755 /opt/ecr-helper/bin/local/docker-credential-ecr-login
    - require:
      - cmd: build_ecr_helper

symlink_ecr_helper:
  file.symlink:
    - target: /opt/ecr-helper/bin/local/docker-credential-ecr-login
    - name: /usr/bin/docker-credential-ecr-login
    - require:
      - cmd: build_ecr_helper
