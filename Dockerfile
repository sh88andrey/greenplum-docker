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
#RUN ./gpadmin_user.sh
#RUN usermod -aG sudo gpadmin
RUN locale-gen en_US.UTF-8 && \
    ssh-keygen -t rsa -N "" -f /root/.ssh/id_rsa && \
    cat /root/.ssh/id_rsa.pub >> /root/.ssh/authorized_keys && \
    chmod 0600 /root/.ssh/authorized_keys && \
    echo "root:password" | chpasswd 2> /dev/null && \
    #
    sed -i -e 's|Defaults    requiretty|#Defaults    requiretty|' /etc/sudoers && \
    sed -ri 's/UsePAM yes/UsePAM no/g;s/PasswordAuthentication yes/PasswordAuthentication no/g' /etc/ssh/sshd_config && \
    sed -ri 's@^HostKey /etc/ssh/ssh_host_ecdsa_key$@#&@;s@^HostKey /etc/ssh/ssh_host_ed25519_key$@#&@' /etc/ssh/sshd_config && \
    service ssh start && \
    { ssh-keyscan localhost; ssh-keyscan 0.0.0.0; } >> /root/.ssh/known_hosts && \
    # create user gpadmin since GPDB cannot run under root
    groupadd -g 1000 gpadmin && useradd -u 1000 -g 1000 gpadmin -s /bin/bash && \
    echo "gpadmin  ALL=(ALL)       NOPASSWD: ALL" > /etc/sudoers.d/gpadmin && \
    groupadd supergroup && usermod -a -G supergroup gpadmin && \
    mkdir -p /home/gpadmin/.ssh && \
    ssh-keygen -t rsa -N "" -f /home/gpadmin/.ssh/id_rsa && \
    cat /home/gpadmin/.ssh/id_rsa.pub >> /home/gpadmin/.ssh/authorized_keys && \
    chmod 0600 /home/gpadmin/.ssh/authorized_keys && \
    echo "gpadmin:password" | chpasswd 2> /dev/null && \
    { ssh-keyscan localhost; ssh-keyscan 0.0.0.0; } >> /home/gpadmin/.ssh/known_hosts && \
    chown -R gpadmin:gpadmin /home/gpadmin

RUN echo 'StrictHostKeyChecking no' > "/home/gpadmin/.ssh/config" && \
chmod 600 /home/gpadmin/.ssh/config && \
chown -R gpadmin:gpadmin /home/gpadmin

RUN echo 'StrictHostKeyChecking no' > "/root/.ssh/config" && \
chmod 600 /root/.ssh/config



#RUN ln -s /opt/greenplum-db-6-6.13.0 /opt/gpdb
#RUN chown -R gpadmin:gpadmin /opt/gpdb

# create master directory
RUN mkdir -p /data/master
#RUN mkdir /data/master/gpseg-1
# create data directories
RUN mkdir -p /data/segment/primary
RUN mkdir /data/segment/mirror

# set locale
ENV LANG en_US.UTF-8  
ENV LANGUAGE en_US:en  
ENV LC_ALL en_US.UTF-8 

WORKDIR /var/lib/gpdb/setup/

#REPLACE WITH "ADD hostlist ." to specify segment nodes
ADD hostlist .
ADD multihost .
ADD singlehost .
ADD allhost .
ADD gpinitsys .
ADD hosts.sh .
ADD hosts .
RUN chmod 755 hosts.sh
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
#RUN echo 'gpadmin ALL=(ALL) NOPASSWD:/usr/sbin/sshd' >> /etc/sudoers


USER gpadmin

ENV GPHOME=/usr/local/greenplum-db
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

# CMD ["./monitor_master.sh"]
