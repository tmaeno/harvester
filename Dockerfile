# non default Dockerfile since Condor 9 doesn't support AL9

ARG PYTHON_VERSION=3.11.4

FROM docker.io/almalinux:9.4

ARG PYTHON_VERSION

RUN dnf update -y
RUN dnf install -y epel-release
RUN dnf install -y yum-utils
RUN yum-config-manager --enable crb

RUN dnf install -y --allowerasing gcc make less git psmisc curl voms-clients-cpp wget httpd logrotate procps mod_ssl \
    openssl-devel readline-devel bzip2-devel libffi-devel zlib-devel passwd voms-clients-java which mysql-devel mariadb \
    sudo vim htop

# install python
RUN mkdir /tmp/python && cd /tmp/python && \
    wget https://www.python.org/ftp/python/${PYTHON_VERSION}/Python-${PYTHON_VERSION}.tgz && \
    tar -xzf Python-*.tgz && rm -f Python-*.tgz && \
    cd Python-* && \
    ./configure --enable-shared --enable-optimizations --with-lto && \
    make altinstall && \
    echo /usr/local/lib > /etc/ld.so.conf.d/local.conf && ldconfig && \
    cd / && rm -rf /tmp/pyton

# install condor
RUN mkdir -p /data/condor; cd /data/condor; \
    wget https://research.cs.wisc.edu/htcondor/tarball/9.0/9.0.17/release/condor-9.0.17-x86_64_CentOS7-stripped.tar.gz -O condor.tar.gz.9; \
    curl -fsSL https://get.htcondor.org | /bin/bash -s -- --download --channel stable; \
    mv condor.tar.gz condor.tar.gz.stable; \
    curl -fsSL https://get.htcondor.org | /bin/bash -s -- --download; \
    ln -fs condor.tar.gz condor.tar.gz.latest
    
#install gcloud
RUN echo $'[google-cloud-cli] \n\
name=Google Cloud CLI \n\
baseurl=https://packages.cloud.google.com/yum/repos/cloud-sdk-el9-x86_64 \n\
enabled=1 \n\
gpgcheck=1 \n\
repo_gpgcheck=0 \n\
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg \n\
       https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg \n ' > /etc/yum.repos.d/google-cloud-sdk.repo

# download and install google rpms avoiding conflicts between google-cloud-sdk and google-cloud-cli
RUN mkdir /tmp/gtemp &&  \
    dnf install -y --downloadonly --downloaddir=/tmp/gtemp google-cloud-sdk-gke-gcloud-auth-plugin && \
    dnf install -y --downloadonly --downloaddir=/tmp/gtemp kubectl && \
    rpm -Uvh --force --nodeps /tmp/gtemp/*.rpm && \
    rm -rf /tmp/gtemp

# install voms
RUN dnf install -y https://repo.opensciencegrid.org/osg/3.6/el9/release/x86_64/osg-ca-certs-1.114-2.osg36.el9.noarch.rpm
RUN dnf install -y https://repo.opensciencegrid.org/osg/3.6/el9/release/x86_64/vo-client-131-1.osg36.el9.noarch.rpm

# setup venv with pythonX.Y
RUN python$(echo ${PYTHON_VERSION} | sed -E 's/\.[0-9]+$//') -m venv /opt/harvester
RUN /opt/harvester/bin/pip install -U pip
RUN /opt/harvester/bin/pip install -U setuptools
RUN /opt/harvester/bin/pip install -U gnureadline
RUN /opt/harvester/bin/pip install -U mysqlclient uWSGI pyyaml
RUN /opt/harvester/bin/pip install -U kubernetes
RUN mkdir /tmp/src
WORKDIR /tmp/src
COPY . .
RUN /opt/harvester/bin/pip install -U .
WORKDIR /
RUN rm -rf /tmp/src

RUN mv /opt/harvester/etc/sysconfig/panda_harvester.rpmnew.template /opt/harvester/etc/sysconfig/panda_harvester
RUN mv /opt/harvester/etc/panda/panda_common.cfg.rpmnew /opt/harvester/etc/panda/panda_common.cfg
RUN mv /opt/harvester/etc/panda/panda_harvester.cfg.rpmnew.template /opt/harvester/etc/panda/panda_harvester.cfg
RUN mv /opt/harvester/etc/panda/panda_harvester-uwsgi.ini.rpmnew.template /opt/harvester/etc/panda/panda_harvester-uwsgi.ini
RUN mv /opt/harvester/etc/rc.d/init.d/panda_harvester-uwsgi.rpmnew.template /opt/harvester/etc/rc.d/init.d/panda_harvester-uwsgi

RUN cp /opt/harvester/local/bin/harvester-admin.rpmnew /opt/harvester/local/bin/harvester-admin && \
    chmod a+x /opt/harvester/local/bin/harvester-admin

RUN ln -fs /opt/harvester/etc/queue_config/panda_queueconfig.json /opt/harvester/etc/panda/panda_queueconfig.json

RUN adduser atlpan
RUN groupadd zp
RUN usermod -a -G zp atlpan
RUN passwd -d atlpan

RUN mkdir -p /var/log/panda
RUN chown -R atlpan:zp /var/log/panda

RUN mkdir -p /data/harvester
RUN chown -R atlpan:zp /data/harvester

# to run with non-root PID
RUN mkdir -p /etc/grid-security/certificates
RUN chmod -R 777 /etc/grid-security/certificates
RUN chmod -R 777 /data/harvester
RUN chmod -R 777 /data/condor
RUN chmod -R 777 /etc/httpd
RUN chmod -R 777 /etc/vomses

RUN chmod -R 777 /etc/grid-security/vomsdir
RUN chmod -R 777 /var/log/httpd
RUN chmod -R 777 /var/lib/logrotate
RUN mkdir -p /opt/harvester/etc/queue_config && chmod 777 /opt/harvester/etc/queue_config

RUN mv /etc/httpd/conf.d/ssl.conf /etc/httpd/conf.d/ssl.conf.back
COPY docker/httpd.conf /etc/httpd/conf/
COPY docker/ssl-httpd.conf /etc/httpd/conf.d/
RUN mkdir -p /opt/harvester/etc/certs
RUN chmod -R 777 /opt/harvester/etc/certs
RUN ln -fs /opt/harvester/etc/certs/hostkey.pem /etc/grid-security/hostkey.pem
RUN ln -fs /opt/harvester/etc/certs/hostcert.pem /etc/grid-security/hostcert.pem
RUN ln -fs /opt/harvester/etc/certs/chain.pem /etc/grid-security/chain.pem
RUN openssl req -x509 -nodes -newkey rsa:2048 -keyout /etc/pki/tls/private/localhost.key \
    -out /etc/ssl/certs/localhost.crt \
    -subj "/C=XX/ST=StateName/L=CityName/O=CompanyName/OU=CompanySectionName/CN=CommonNameOrHostname"
RUN chmod 644 /etc/pki/tls/private/localhost.key
RUN chmod 644 /etc/pki/tls/certs/localhost.crt

RUN dnf clean all && rm -rf /var/cache/yum

# make lock dir
ENV PANDA_LOCK_DIR /var/run/panda
RUN mkdir -p ${PANDA_LOCK_DIR} && chmod 777 ${PANDA_LOCK_DIR}

# make a wrapper script to launch services and periodic jobs in non-root container
RUN echo $'#!/bin/bash \n\
set -m \n\
/data/harvester/init-harvester \n\
/data/harvester/run-harvester-crons & \n\
source /data/harvester/setup-harvester \n\
\n\
# if no host certificate \n\
if [[ ! -f /opt/harvester/etc/certs/hostkey.pem ]]; then \n\
    ln -s /etc/pki/tls/certs/localhost.crt   /opt/harvester/etc/certs/hostcert.pem \n\
    ln -s /etc/pki/tls/private/localhost.key /opt/harvester/etc/certs/hostkey.pem \n\
    ln -s /etc/pki/tls/certs/ca-bundle.crt   /opt/harvester/etc/certs/chain.pem \n\
fi \n\
\n\
cd /data/condor \n\
tar -x -f condor.tar.gz${CONDOR_CHANNEL} \n\
mv condor-*stripped condor \n\
cd condor \n\
./bin/make-personal-from-tarball \n\
. condor.sh \n\
ln -s /data/harvester/condor_config.local /data/condor/condor/local/config.d/ \n\
condor_master \n\
/sbin/httpd \n\
/opt/harvester/etc/rc.d/init.d/panda_harvester-uwsgi start \n ' > /opt/harvester/etc/rc.d/init.d/run-harvester-services

RUN chmod +x /opt/harvester/etc/rc.d/init.d/run-harvester-services

# add condor setup ins sysconfig
RUN echo source /data/condor/condor/condor.sh >> /opt/harvester/etc/sysconfig/panda_harvester
RUN echo source /data/harvester/setup-harvester >> /opt/harvester/etc/sysconfig/panda_harvester

CMD exec /bin/bash -c "trap : TERM INT; sleep infinity & wait"

EXPOSE 8080 8443
