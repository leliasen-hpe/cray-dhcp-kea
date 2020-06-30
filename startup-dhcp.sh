#!/bin/bash

#  check username and passward are empty
#  this can happen if the pod restarts
if [ -z "$DHCP_DBUSER" ]
then
      DHCP_DBUSER=$(cat /secrets/postgres/dhcpdsuser/username)
fi
if [ -z "$DHCP_DBPASS" ]
then
      DHCP_DBPASS=$(cat /secrets/postgres/dhcpdsuser/password)
fi

# check for db
PGPASSWORD=$DHCP_DBPASS
pg_uri="postgres://$DHCP_DBUSER@$DHCP_DBHOST:5432/"
count=0

# make sure pg is ready to accept connections
until pg_isready -h $DHCP_DBHOST -p 5432 -U $DHCP_DBUSER
do
  echo "Waiting for postgres at: $pg_uri"
  ((count++))
  sleep 60;
  if [ $count -gt 10 ]
  then
    echo "timeout waiting for postgres and exiting"
    exit 1
  fi
done

PGPASSWORD=$DHCP_DBPASS /bin/sh -c "/usr/bin/psql -h $DHCP_DBHOST -U $DHCP_DBUSER -d $DHCP_DBNAME -a -f dhcpdb_create.sql"


mkdir -p /usr/local/kea
#  since the username and password is dyanmic with the k8s postgres operator
#  we output the config file and substitute the environment variables
( echo "cat <<EOF" ; cat /cray-dhcp-kea-dhcp4.conf ; echo EOF ) | sh > /usr/local/kea/cray-dhcp-kea-dhcp4.conf
#  clean up
sed -i 's/EOF//g' /usr/local/kea/cray-dhcp-kea-dhcp4.conf
#  helpful for debugging
cat /usr/local/kea/cray-dhcp-kea-dhcp4.conf
# what we use to run Cray DHCP Kea server
nohup /usr/local/sbin/kea-dhcp4 -c /usr/local/kea/cray-dhcp-kea-dhcp4.conf &
# we will need to tune this
while true; do /dhcp-helper.py; sleep ${DHCP_HELPER_INTERVAL_SECONDS}; done
