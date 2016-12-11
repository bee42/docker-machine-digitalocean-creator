FROM docker:1.13.0-rc3-dind
MAINTAINER Peter Rossbach <peter.rossbach@bee42.com> @PRossbach

ARG COMPOSE_VERSION
ARG MACHINE_VERSION
ARG GLIBC_VERSION
ARG DOCTL_VERSION

ENV COMPOSE_VERSION=${COMPOSE_VERSION:-1.9.0} \
  MACHINE_VERSION=${MACHINE_VERSION:-0.9.0-rc2} \
  PORT=2375 \
  GLIBC_VERSION=${GLIC_VERSION:-2.23-r3} \
  DOCTL_VERSION=${DOCTL_VERSION:-1.5.0}

RUN apk add --update ca-certificates openssl curl && \
    curl -o glibc.apk -L "https://github.com/andyshinn/alpine-pkg-glibc/releases/download/${GLIBC_VERSION}/glibc-${GLIBC_VERSION}.apk" && \
    apk add --allow-untrusted glibc.apk && \
    curl -o glibc-bin.apk -L "https://github.com/andyshinn/alpine-pkg-glibc/releases/download/${GLIBC_VERSION}/glibc-bin-${GLIBC_VERSION}.apk" && \
    apk add --allow-untrusted glibc-bin.apk && \
    /usr/glibc-compat/sbin/ldconfig /lib /usr/glibc/usr/lib && \
    echo 'hosts: files mdns4_minimal [NOTFOUND=return] dns mdns4' >> /etc/nsswitch.conf && \
    rm -f glibc.apk glibc-bin.apk && \
    rm -rf /var/cache/apk/*

# digital ocean cli
RUN curl -o doctl.tar.gz -L https://github.com/digitalocean/doctl/releases/download/v${DOCTL_VERSION}/doctl-${DOCTL_VERSION}-linux-amd64.tar.gz \
  && tar xzf doctl.tar.gz \
  && mv ./doctl /usr/local/bin \
  && rm -f doctl.tar.gz

# install supervisor
RUN echo http://nl.alpinelinux.org/alpine/edge/testing >> /etc/apk/repositories \
  && apk add --update \
	supervisor sudo openssh pwgen jq zip unzip bash bash-completion\
	&& rm -rf /var/cache/apk/* \
  && mkdir -p /var/log/supervisor \
  && mkdir /var/run/sshd \
  && echo 'root:screencast' |chpasswd \
  && sed -i 's/#PermitRootLogin no/PermitRootLogin yes/g' /etc/ssh/sshd_config

ADD completion.txt /tmp/completion.txt
ADD mobydock.txt /tmp/mobydock.txt

RUN  mkdir -p /etc/bash_completion.d \
  && curl -Ls https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-`uname -s`-`uname -m` > /usr/local/bin/docker-compose ; chmod +x /usr/local/bin/docker-compose \
  && curl -Ls https://raw.githubusercontent.com/docker/compose/${COMPOSE_VERSION}/contrib/completion/bash/docker-compose > /etc/bash_completion.d/docker-compose ; chmod +x /etc/bash_completion.d/docker-compose \
  && curl -Ls https://raw.githubusercontent.com/docker/docker/master/contrib/completion/bash/docker > /etc/bash_completion.d/docker ; chmod +x /etc/bash_completion.d/docker \
  && curl -L https://github.com/docker/machine/releases/download/${MACHINE_VERSION}/docker-machine-`uname -s`-`uname -m` >/usr/local/bin/docker-machine ; chmod +x /usr/local/bin/docker-machine \
  && curl -Ls https://raw.githubusercontent.com/docker/machine/${MACHINE_VERSION}/contrib/completion/bash/docker-machine.bash > /etc/bash_completion.d/docker-machine ; \
  chmod +x /etc/bash_completion.d/docker-machine \
  && curl -Ls https://raw.githubusercontent.com/docker/machine/${MACHINE_VERSION}/contrib/completion/bash/docker-machine-prompt.bash > /etc/bash_completion.d/docker-machine-prompt ; \
  chmod +x /etc/bash_completion.d/docker-machine-prompt \
  && curl -Ls https://raw.githubusercontent.com/docker/machine/${MACHINE_VERSION}/contrib/completion/bash/docker-machine-wrapper.bash > /etc/bash_completion.d/docker-machine-wrapper ; \
  chmod +x /etc/bash_completion.d/docker-machine-wrapper \
  && cat >>/etc/profile </tmp/completion.txt

# add developer user creator
RUN addgroup creator && addgroup docker \
  && adduser -D -G docker -s /bin/bash creator creator \
  && echo "%docker  ALL=(ALL)      ALL" >>/etc/sudoers \
  && echo 'creator:creator' | chpasswd \
  && echo "export DOCKER_HOST=tcp://0.0.0.0:$PORT" >>/home/creator/.bash_aliases \
  && echo "alias d=docker" >>/home/creator/.bash_aliases \
  && echo "alias dm=docker-machine" >>/home/creator/.bash_aliases \
  && echo "alias dco=docker-compose" >>/home/creator/.bash_aliases \
  && echo ":set term=ansi" >>/home/creator/.vimrc \
  && cp /tmp/mobydock.txt /home/creator/.mobydock.txt \
  && echo "cat /home/creator/.mobydock.txt" > /home/creator/.profile \
  && echo ". /home/creator/.bash_aliases" >> /home/creator/.profile \
  && echo "PS1='[\u@\h \W\$(__docker_machine_ps1)]\\\$ '" >> /home/creator/.profile \
  && chown -R creator:creator /home/creator

ADD ssh_config /home/creator/.ssh/config
RUN chown -R creator:creator /home/creator/.ssh

# Configuration supervisord
ADD supervisord-base.ini /etc/supervisor.d/supervisord-base.ini
# Configuration dind
ADD supervisord-docker.ini /etc/supervisor.d/supervisord-docker.ini
ADD supervisord-sshd.ini /etc/supervisor.d/supervisord-sshd.ini

EXPOSE 9001 2375 22
VOLUME [ "/data" ]

ADD start.sh /usr/local/bin/start.sh
ENTRYPOINT [ "/usr/local/bin/start.sh" ]
CMD []

LABEL org.label-schema.name="do-creator"  \
 org.label-schema.vendor="bee42 solutions gmbh" \
 org.label-schema.schema-version="1.0" \
 org.label-schema.description="DigitalOcean cli docker machine creator DinD" \
 org.label-schema.license.type="Apache 2.0" \
 org.label-schema.license.path="/etc/LICENSE.do-creator"

ADD LICENSE /etc/LICENSE.do-creator
RUN COPYDATE=`date  +'%Y'` \
 && echo "infrabricks digitalocean machine creator dind" >/etc/provisioned.do-creator \
 && date >>/etc/provisioned.do-creator \
 && echo >>/etc/provisioned.do-creator \
 && echo " Copyright ${COPYDATE} by <peter.rossbach@bee42.com> bee42 solutions gmbh" >>/etc/provisioned.do-creator
