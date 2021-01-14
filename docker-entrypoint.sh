#!/bin/bash
sudo /usr/sbin/sshd

# create master directory
sudo chown -R gpadmin:gpadmin /data
# create data directories
source ${GPHOME}/greenplum_path.sh

m="master"
s="standby"
if [ "$GP_NODE" == "$m" ]

then
    echo 'Node type='$GP_NODE
    if [ ! -d $MASTER_DATA_DIRECTORY ]; then
        mkdir /data/master
        echo 'Master directory does not exist. Initializing master from gpinitsystem_reflect.'
        yes | cp $HOSTFILE multilist
        gpssh-exkeys -f multilist
        echo "Key exchange complete"
        yes | gpinitsystem -a  -c gpinitsys --su_password=dataroad -s db_standby
        echo "Master node initialized"
        # receive connection from anywhere.. This should be changed!!
        echo "host all all 0.0.0.0/0 md5" >>/data/master/gpseg-1/pg_hba.conf
	# init stand by
	# yes | gpinitstandby -s db_standby_1
        gpstop -u
    else
        echo 'Master exists. Restarting gpdb.'
        gpstart -a
    fi
elif [ "$GP_NODE" == "$s" ]

then
    echo 'Node type='$GP_NODE
    mkdir -p /data/master
else
    echo 'Node type='$GP_NODE
    mkdir -p /data/segment/primary
    mkdir /data/segment/mirror
fi
exec "$@"
