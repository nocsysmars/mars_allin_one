FROM fedora:33

USER root

ENV PYTHONDONTWRITEBYTECODE yes

ARG ovnver=ovn-21.03.0-32.fc33

# install needed rpms - openvswitch must be 2.10.4 or higher
RUN INSTALL_PKGS="ovn ovn-central ovn-host koji" && \
	dnf install --best --refresh -y --setopt=tsflags=nodocs $INSTALL_PKGS && \
	dnf clean all && rm -rf /var/cache/dnf/*

RUN mkdir -p /var/run/openvswitch

RUN koji download-build $ovnver --arch=x86_64
RUN rpm -Uhv --nodeps --force *.rpm


WORKDIR /root
