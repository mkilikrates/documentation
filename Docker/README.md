# Using Docker to test without install anything

This is a simple list of examples where you can use docker to make tests without depends on local installation.

## Connecting to Databases

Some simple use cases

### Postgres SQL

[Official documentation about this image](https://hub.docker.com/_/postgres)

It will ask for password

'''bash
export POSTGRES_HOST='<plsql hostname or ip to connect>'
export POSTGRES_PORT='<port to connect>' # usually 5432
export POSTGRES_DB='<database name to connect>'
export POSTGRES_PASSWORD='<Database password>'
export POSTGRES_USER='<Database user name>'
docker run --name plsqlclient -it --rm postgres plsql -h $POSTGRES_HOST -p $POSTGRES_PORT -d $POSTGRES_DB -u $POSTGRES_USER -W
'''

or

'''bash
export POSTGRES_HOST='<plsql hostname or ip to connect>'
export POSTGRES_PORT='<port to connect>' # usually 5432
export POSTGRES_DB='<database name to connect>'
export POSTGRES_PASSWORD='<Database password>'
export POSTGRES_USER='<Database user name>'
docker run --name plsqlclient -it --rm postgres plsql postgresql://$POSTGRES_USER':'$POSTGRES_PASSWORD'@'$POSTGRES_HOST':'$POSTGRES_PORT'/'$POSTGRES_DB
'''

### Oracle Instant Client

[Official documentation about this image](https://github.com/oracle/docker-images/blob/main/OracleInstantClient/README.md)

'''bash
export DB_HOST='<database hostname or ip to connect>'
export DB_PORT='<port to connect>' # usually 1521
export DB_SERVICE='<Service name to connect>'
export DB_PASSWORD='<Database password>'
export DB_USER='<Database user name>'
docker run --name orainstcli -it --rm ghcr.io/oracle/oraclelinux8-instantclient:21 sqlplus $DB_USER'/'$DB_PASSWORD'@'$DB_HOST':'$DB_PORT'/'$DB_SERVICE
'''

