FROM ubuntu:20.04 as builder
MAINTAINER Daniel Guerra

# Install packages

ENV DEBIAN_FRONTEND noninteractive
RUN sed -i "s/# deb-src/deb-src/g" /etc/apt/sources.list
RUN apt-get -y update
RUN apt-get -yy upgrade
ENV BUILD_DEPS="git autoconf pkg-config libssl-dev libpam0g-dev \
    libx11-dev libxfixes-dev libxrandr-dev nasm xsltproc flex \
    bison libxml2-dev dpkg-dev libcap-dev wget"
RUN apt-get -yy install  sudo apt-utils software-properties-common $BUILD_DEPS


# Build xrdp
WORKDIR /tmp
RUN apt-get source pulseaudio
RUN apt-get build-dep -yy pulseaudio
WORKDIR /tmp/pulseaudio-13.99.1
RUN dpkg-buildpackage -rfakeroot -uc -b
WORKDIR /tmp
RUN git clone --branch devel --recursive https://github.com/neutrinolabs/xrdp.git
WORKDIR /tmp/xrdp
RUN ./bootstrap
RUN ./configure
RUN make
RUN make install
WORKDIR /tmp
RUN  apt -yy install libpulse-dev
RUN git clone --recursive https://github.com/neutrinolabs/pulseaudio-module-xrdp.git
WORKDIR /tmp/pulseaudio-module-xrdp
RUN ./bootstrap && ./configure PULSE_DIR=/tmp/pulseaudio-13.99.1
RUN make
RUN mkdir -p /tmp/so
RUN cp src/.libs/*.so /tmp/so

# compile xrdp_0.9.15 deb file
WORKDIR /tmp
RUN wget http://archive.ubuntu.com/ubuntu/pool/universe/x/xrdp/xrdp_0.9.15.orig.tar.gz && \
  wget http://archive.ubuntu.com/ubuntu/pool/universe/x/xrdp/xrdp_0.9.15-1ubuntu1.debian.tar.xz
RUN tar xvzf xrdp_0.9.15.orig.tar.gz
WORKDIR /tmp/xrdp-0.9.15
RUN tar xf ../xrdp_0.9.15-1ubuntu1.debian.tar.xz
RUN apt-get build-dep -yy xrdp --option=Dpkg::Options::=--force-confdef
RUN dpkg-buildpackage -rfakeroot -uc -b

# compile xrdp_0.9.15 deb file
WORKDIR /tmp
RUN wget http://archive.ubuntu.com/ubuntu/pool/universe/x/xorgxrdp/xorgxrdp_0.2.15.orig.tar.gz && \
  wget http://archive.ubuntu.com/ubuntu/pool/universe/x/xorgxrdp/xorgxrdp_0.2.15-1.debian.tar.xz
RUN tar xvzf xorgxrdp_0.2.15.orig.tar.gz
WORKDIR /tmp/xorgxrdp-0.2.15
RUN tar xf ../xorgxrdp_0.2.15-1.debian.tar.xz
RUN apt-get build-dep -yy xorgxrdp --option=Dpkg::Options::=--force-confdef
RUN apt-get install -y /tmp/xrdp_0.9.15-1ubuntu1_amd64.deb --option=Dpkg::Options::=--force-confdef
RUN dpkg-buildpackage -rfakeroot -uc -b

FROM ubuntu:20.04
ARG ADDITIONAL_PACKAGES=""
ENV ADDITIONAL_PACKAGES=${ADDITIONAL_PACKAGES}
ENV DEBIAN_FRONTEND noninteractive
RUN apt update && apt install -y software-properties-common apt-utils
RUN add-apt-repository "deb http://archive.canonical.com/ $(lsb_release -sc) partner" && apt update
RUN mkdir -p /tmp/debs
COPY --from=builder /tmp/xrdp_0.9.15-1ubuntu1_amd64.deb /tmp/debs
COPY --from=builder /tmp/xorgxrdp_0.2.15-1_amd64.deb /tmp/debs
RUN apt update &&  apt -y full-upgrade && apt-get install -y \
  ca-certificates \
  crudini \
  locales \
  pulseaudio \
  supervisor \
  uuid-runtime \
  xauth \
  xautolock \
  xfce4 \
  xfce4-clipman-plugin \
  xfce4-screenshooter \
  xfce4-taskmanager \
  xfce4-terminal \
  xfce4-xkb-plugin \
  /tmp/debs/xorgxrdp_0.2.15-1_amd64.deb \
  xprintidle \
  /tmp/debs/xrdp_0.9.15-1ubuntu1_amd64.deb \
  $ADDITIONAL_PACKAGES && \
  apt remove -y light-locker xscreensaver && \
  apt autoremove -y && \
  rm -rf /var/cache/apt /var/lib/apt/lists && \
  mkdir -p /var/lib/xrdp-pulseaudio-installer
COPY --from=builder /tmp/so/module-xrdp-source.so /var/lib/xrdp-pulseaudio-installer
COPY --from=builder /tmp/so/module-xrdp-sink.so /var/lib/xrdp-pulseaudio-installer
ADD bin /usr/bin
ADD etc /etc
ADD autostart /etc/xdg/autostart

# Configure
RUN mkdir /var/run/dbus && \
  cp /etc/X11/xrdp/xorg.conf /etc/X11 && \
  sed -i "s/console/anybody/g" /etc/X11/Xwrapper.config && \
  sed -i "s/xrdp\/xorg/xorg/g" /etc/xrdp/sesman.ini && \
  locale-gen en_US.UTF-8 && \
  echo "pulseaudio -D --enable-memfd=True" > /etc/skel/.Xsession && \
  echo "xfce4-session" >> /etc/skel/.Xsession && \
  rm -rf /etc/xrdp/rsakeys.ini /etc/xrdp/*.pem /tmp/debs

# Docker config
VOLUME ["/home"]
EXPOSE 3389 22 9001
ENTRYPOINT ["/usr/bin/docker-entrypoint.sh"]
CMD ["supervisord"]
