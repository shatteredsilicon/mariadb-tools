#!/bin/bash
# AUTHOR: Cole Busby (mariadb-colebusby, cole.busby@mariadb.com)
# This script is intended to be ran from the sandbox directory of maria-tools.

SYNCUSER=msandbox

# create dirs
for j in 'primary' 'secondary' 'tertiary'; do
    for i in 'configs' 'data' 'run'; do
        mkdir -p ./tmp/$j/$i
    done
done
if [[ ! -f /tmp/12345 ]]; then
	ln -s `pwd`/tmp/primary /tmp/12345                                                                     # TODO: Genercize location by using variables.
	ln -s `pwd`/tmp/secondary /tmp/12346                                                                   # TODO: Genercize location by using variables.
	ln -s `pwd`/tmp/tertiary /tmp/12347                                                                    # TODO: Genercize location by using variables.
fi

let id=1
for i in 12345 12346 12347; do
# unpack initial datas
cp ./base_configs/my.client.cnf /tmp/$i/configs/mariadb-client.cnf
cp ./base_configs/my.sandbox.cnf /tmp/$i/configs/my.cnf
sed -i'' "s:PORT:$i:g" /tmp/$i/configs/my.cnf
sed -i'' "s:NAME:maria$i:g" /tmp/$i/configs/my.cnf
sed -i'' "s:ID:$id:g" /tmp/$i/configs/my.cnf
sed -i'' "s:PORT:$i:g" /tmp/$i/configs/mariadb-client.cnf
chmod 755 /tmp/$i/configs/mariadb-client.cnf
cp ./base_configs/use.template /tmp/$i/use
sed -i'' "s:PORT:$i:g" /tmp/$i/use
((id++))
done

# Start cluster
docker-compose up -d

# This sleep is required so that we can ensure the server stands up
echo "Quick pause to let the DBs warm..."
sleep 60
echo "Let's try continuing..."

# feed the servers basic data
for i in '12345' '12346' '12347'; do
    mysql -h 127.0.0.1 -u root -pskysql -P $i < prepper.sql
    sleep 5
    if [[ $? -ne 0 ]]; then
	echo "FATAL: something happened."
	exit 2
    fi
done

# create replication
mysql -h 127.0.0.1 -u $SYNCUSER -p$SYNCUSER -P 12345 -e "FLUSH TABLES WITH READ LOCK;"
sleep 2
export LOG=`mysql -h 127.0.0.1 -u $SYNCUSER -p$SYNCUSER -P 12345 -e "show master status;"| tail -n 1 | awk '{print $1}'`
sleep 2
export POS=`mysql -h 127.0.0.1 -u $SYNCUSER -p$SYNCUSER -P 12345 -e "show master status;"| tail -n 1 | awk '{print $2}'`

cat << EOF > repl.sql
CHANGE MASTER TO
MASTER_HOST='mariaprimary',
MASTER_USER='$SYNCUSER',
MASTER_PASSWORD='$SYNCUSER',
MASTER_PORT=3306,
MASTER_LOG_FILE='$LOG',
MASTER_LOG_POS=$POS,
MASTER_CONNECT_RETRY=10;
START SLAVE;
EOF

for i in '12346' '12347'; do
    mysql -h 127.0.0.1 -u $SYNCUSER -p$SYNCUSER -P $i < repl.sql
done

mysql -h 127.0.0.1 -u $SYNCUSER -p$SYNCUSER -P 12345 -e 'UNLOCK TABLES;'
mysql -h 127.0.0.1 -u $SYNCUSER -p$SYNCUSER -P 12347 -e 'SET GLOBAL read_only=1;'
./base_configs/load-sakila-db 12345
../util/check-load-data
./checksum-test-dataset
