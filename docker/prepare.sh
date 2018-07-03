#!/bin/bash
_get_config() {
	local conf="$1"; shift
	"$@" --verbose --help --log-bin-index="$(mktemp -u)" 2>/dev/null | awk '$1 == "'"$conf"'" { print $2; exit }'
}



mysqld --no-defaults --user=mysql --innodb-page-size=$INNODB_PAGE_SIZE --skip-networking --socket=/tmp/mysqld.sock --datadir=$DATADIR &
pid="$!"
mysql=( mysql --protocol=socket -uroot -hlocalhost --socket="/tmp/mysqld.sock" )

		for i in {30..0}; do
			if echo 'SELECT 1' | "${mysql[@]}" &> /dev/null; then
				break
			fi
			echo "Waiting for mysqld to come UP... $i"
			sleep 1
		done
mysql_tzinfo_to_sql /usr/share/zoneinfo | "${mysql[@]}" mysql
echo ">>> Creating user";
"${mysql[@]}" <<-EOSQL
    -- What's done in this file shouldn't be replicated
    --  or products like mysql-fabric won't work
    SET @@SESSION.SQL_LOG_BIN=0;
    CREATE USER IF NOT EXISTS '${USER}'@'${HOST}' IDENTIFIED BY '${PASSWORD}';
    ALTER USER '${USER}'@'${HOST}' IDENTIFIED BY '${PASSWORD}' ;
    GRANT ALL ON *.* TO '${USER}'@'${HOST}';
    FLUSH PRIVILEGES ;
EOSQL


rc=$?; if [ $rc != 0 ]; then exit $rc; fi

"${mysql[@]}" <<-EOSQL
    SELECT User, Host FROM mysql.user;
EOSQL

echo "<<< Creating user";
echo "SHUTDOWN;" | "${mysql[@]}" mysql

if ! wait "$pid"; then
    echo >&2 'mysqld did not properly exit.'
    exit 1
fi

#rm /var/lib/mysql-template/ib_logfile*