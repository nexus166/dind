FROM    debian:buster-slim
SHELL   ["/bin/bash", "-euvxo", "pipefail", "-c"]

RUN     printf 'hosts: files dns\n' | tee /etc/nsswitch.conf

ARG     OS_ARCH=amd64
ARG     OS_REL=buster

RUN	export DEBIAN_FRONTEND="noninteractive"; \
        apt-get update; \
        apt-get dist-upgrade -y; \
        apt-get install -y --no-install-recommends \
                        apparmor apt-transport-https aufs-tools bash ca-certificates \
			cgroupfs-mount curl e2fsprogs expect gnupg2 iproute2 iptables \
			iputils-* kmod libltdl7 pigz procps sudo wget xz-utils; \
        export _OS="$(grep -Eio 'ubuntu|debian' /etc/*rel* | cut -d':' -f2 | tr '[[:upper:]]' '[[:lower:]]' | sort | uniq -c | sort -k1,1nr | awk 'NR==1{print $2}')"; \
        curl -fsSLo- "https://download.docker.com/linux/${_OS}/gpg" | apt-key add -; \
        printf "deb [arch=%s] https://download.docker.com/linux/%s %s stable\\n" "${OS_ARCH}" "${_OS}" "${OS_REL}" | tee /etc/apt/sources.list.d/docker.list; \
        apt-get update; \
        apt-get install -y --no-install-recommends containerd.io docker-ce docker-ce-cli; \
	apt-get clean; \
        apt-get autoclean; \
        rm -vrf /var/lib/apt/lists/* /tmp/* /var/tmp/* /var/cache/* ~/.cache

RUN	addgroup --system dockremap; \
        adduser --system --ingroup dockremap dockremap; \
        printf 'dockremap:165536:65536\n' | tee -a /etc/subuid; \
        printf 'dockremap:165536:65536\n' | tee -a /etc/subgid

ARG     user=dind
RUN     export GRPID="$(shuf -i 2000-3000 -n1)"; \
        addgroup --gid "${GRPID}" --system "${user}" ; \
        export USRID="$(shuf -i 3000-4000 -n1)"; \
        useradd  --no-create-home --system --shell "/sbin/nologin" --gid "${GRPID}" --groups docker,sudo --uid "${USRID}" "${user}"; \
        printf '%s ALL=(ALL) NOPASSWD: ALL\n' "${user}" >> /etc/sudoers


ADD     https://raw.githubusercontent.com/moby/moby/master/hack/dind                            /usr/local/bin/dind
ADD     https://raw.githubusercontent.com/docker-library/docker/master/dockerd-entrypoint.sh    /usr/local/bin/dockerd-entrypoint.sh
RUN     printf '#!/bin/bash -evx\n/bin/bash -c "sudo /usr/local/bin/dockerd-entrypoint.sh dockerd --host=tcp://${DOCKER_ADDR:-"127.0.0.1"}:${DOCKER_PORT:-"2375"}"\n' | tee /usr/local/bin/entrypoint.sh; \
        chmod -v a+rx /usr/local/bin/dind /usr/local/bin/dockerd-entrypoint.sh /usr/local/bin/entrypoint.sh

USER    "${user}"

ARG	DOCKER_PORT=2375
ARG	DOCKER_ADDR="127.0.0.1"
EXPOSE	${DOCKER_PORT}
ENV	DOCKER_HOST="tcp://${DOCKER_ADDR}:${DOCKER_PORT}"

VOLUME	/var/lib/docker

SHELL   ["/bin/bash", "-c"]
ENTRYPOINT ["entrypoint.sh"]
