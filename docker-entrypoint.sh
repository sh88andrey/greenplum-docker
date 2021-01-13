#!/bin/bash
sudo /usr/sbin/sshd

# create master directory
sudo chown -R gpadmin:gpadmin /data
mkdir -p /data/master
mkdir /data/master/gpsne-1
# create data directories
mkdir /data/segment
source ${GPHOME}/greenplum_path.sh

m="master"
if [ "$GP_NODE" == "$m" ]

then
     echo 'Node type='$GP_NODE
    if [ ! -d $MASTER_DATA_DIRECTORY ]; then
        echo 'Master directory does not exist. Initializing master from gpinitsystem_reflect.'
        yes | cp $HOSTFILE hostlist
        gpssh-exkeys -f hostlist
        echo "Key exchange complete"
        gpinitsystem -a  -c gpinitsys --su_password=dataroad
        echo "Master node initialized"
        # receive connection from anywhere.. This should be changed!!
        echo "host all all 0.0.0.0/0 md5" >>/data/master/gpsne-1/pg_hba.conf
        gpstop -u
    else
        echo 'Master exists. Restarting gpdb.'
        gpstart -a
    fi
else
    echo 'Node type='$GP_NODE
fi
exec "$@"
