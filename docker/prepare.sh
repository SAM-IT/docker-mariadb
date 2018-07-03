#!/bin/bash
echo "prepare";

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
echo "SHUTDOWN;" | "${mysql[@]}" mysql

if ! wait "$pid"; then
    echo >&2 'mysqld did not properly exit.'
    exit 1
fi

#rm /var/lib/mysql-template/ib_logfile*