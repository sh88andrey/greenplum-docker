FROM ubuntu:18.04

RUN sed -i s@/archive.ubuntu.com/@/mirrors.aliyun.com/@g  /etc/apt/sources.list \
    && sed -i s@/security.ubuntu.com/@/mirrors.aliyun.com/@g  /etc/apt/sources.list \
    && apt-get update && apt-get install -y openssh-server \
    && apt-get install -y less vim sudo \
    && apt-get install -y software-properties-common \
    && apt-get install -y locales iputils-ping

#RUN add-apt-repository -y ppa:greenplum/db
#ADD greenplum-ubuntu-db-bionic.list /etc/apt/sources.list.d/
ADD greenplum-db-6.13.0-ubuntu18.04-amd64.deb /tmp/
RUN apt-get install -y libapr1 libaprutil1 krb5-multidev libcurl3-gnutls libcurl4 libevent-2.1-6 libyaml-0-2 perl rsync zip net-tools iproute2
RUN dpkg -i /tmp/greenplum-db-6.13.0-ubuntu18.04-amd64.deb

WORKDIR /inst_scripts

# create gpadmin user
ADD gpadmin_user.sh .
RUN chmod 755 gpadmin_user.sh
RUN ./gpadmin_user.sh
RUN usermod -aG sudo gpadmin

#RUN ln -s /opt/greenplum-db-6-6.13.0 /opt/gpdb
#RUN chown -R gpadmin:gpadmin /opt/gpdb

# create master directory
RUN mkdir -p /data/master
#RUN mkdir /data/master/gpseg-1
# create data directories
RUN mkdir -p /data/segment/primary
RUN mkdir /data/segment/mirror

# set locale
RUN locale-gen en_US.UTF-8  
ENV LANG en_US.UTF-8  
ENV LANGUAGE en_US:en  
ENV LC_ALL en_US.UTF-8 

WORKDIR /var/lib/gpdb/setup/

#REPLACE WITH "ADD hostlist ." to specify segment nodes
ADD hostlist .
ADD multihost .
ADD singlehost .
ADD gpinitsys .
RUN chown -R gpadmin:gpadmin /data


ENV USER=gpadmin
ENV MASTER_DATA_DIRECTORY=/data/master/gpseg-1

# add the entrypoint script
ADD docker-entrypoint.sh /usr/local/bin/
ADD monitor_master.sh   .
RUN chmod 755 /usr/local/bin/docker-entrypoint.sh
# add monitor script
RUN chmod +x monitor_master.sh
RUN chown -R gpadmin:gpadmin /var/lib/gpdb

#sshd must exist for gpdb monitor_master.sh
RUN echo 'gpadmin ALL=(ALL) NOPASSWD:/usr/sbin/sshd' >> /etc/sudoers


USER gpadmin

ENV GPHOME=/opt/greenplum-db-6-6.13.0
ENV PYTHONHOME=${GPHOME}/ext/python
ENV PATH=${PYTHONHOME}/bin:${PATH}
ENV LD_LIBRARY_PATH=${PYTHONHOME}/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}
ENV PYTHONPATH=${GPHOME}/lib/python
ENV PATH=${GPHOME}/bin:${PATH}
ENV LD_LIBRARY_PATH=${GPHOME}/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}
ENV OPENSSL_CONF=${GPHOME}/etc/openssl.cnf

ENV GP_NODE=master
#ENV HOSTFILE=singlehost
ENV HOSTFILE=multilist
####CHANGE THIS TO YOUR LOCAL SUBNET

VOLUME /data
ENTRYPOINT ["docker-entrypoint.sh"]
EXPOSE 5432

CMD ["./monitor_master.sh"]
