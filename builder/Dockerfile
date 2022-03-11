
ARG VERSION=20.04
FROM ubuntu:${VERSION}

# Info on it
LABEL maintainer="gbi@grdf.fr" \
      version="2.0" \
      description="BancLib dockerfile's to build it."

# Do the job
RUN echo "Installing basic stuff" \
    && echo "*** Updating ***" \
    && apt-get update \
    && echo "*** -------- ***" \
    && apt-get -y install nano net-tools iputils-ping make \
    && apt-get -y install sudo \
    && id user 2>/dev/null || useradd -u 1000 -U -s /bin/bash -G dialout,sudo -m user \
    && echo 'user:userpwd' | chpasswd \
    && echo "*** -------- ***" \
    && export TZ="Europe/Paris"; apt-get install -y tzdata \
    && apt-get -y install \
        cpanminus \
        libmoose-perl \
        libdevice-serialport-perl \
        libconfig-tiny-perl \
        liblog-log4perl-perl \
        libcrypt-rijndael-perl \
        liblog-dispatch-filerotate-perl \
        libdatetime-perl \
        libxml-libxml-perl \
        libffi-platypus-perl \
        libdata-peek-perl \
    && echo "Installing all required Perl things" \
    && cpanm \   
        Package::Alias \
        Digest::CMAC

USER user
WORKDIR /home/user/tools

