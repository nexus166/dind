FROM	alpine
SHELL   ["/bin/ash", "-euvxo", "pipefail", "-c"]

RUN     printf 'hosts: files dns\n' | tee /etc/nsswitch.conf

RUN	apk add --no-cache --update --upgrade \
		bash ca-certificates docker e2fsprogs iproute2 \
		iptables kmod pigz procps sudo

RUN	addgroup --system dockremap; \
        adduser --system --ingroup dockremap dockremap; \
        printf 'dockremap:165536:65536\n' | tee -a /etc/subuid; \
        printf 'dockremap:165536:65536\n' | tee -a /etc/subgid

ARG     USR="dind"
RUN	export GRPID="$(shuf -i 2000-3000 -n1)"; \
        addgroup --gid "${GRPID}" --system "${USR}" ; \
        export USRID="$(shuf -i 3000-4000 -n1)"; \
	adduser -H -D -S -s /sbin/nologin -g "${USR}" "${USR}"; \
	printf '%s ALL=(ALL) NOPASSWD: ALL\n' "${USR}" | tee -a /etc/sudoers; \
	adduser "${USR}" docker

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
