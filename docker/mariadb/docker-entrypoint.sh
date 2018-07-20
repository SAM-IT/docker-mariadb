#!/bin/bash
set -eo pipefail
shopt -s nullglob

if [ ! -e "/etc/mysql/conf.d/innodb_page_size.cnf" ]; then

    if [ -z "$INNODB_PAGE_SIZE" ]; then
    export INNODB_PAGE_SIZE=16k
    fi
    echo "[mysqld]" > /etc/mysql/conf.d/innodb_page_size.cnf
    echo "innodb_page_size=$INNODB_PAGE_SIZE" >> /etc/mysql/conf.d/innodb_page_size.cnf
fi




# if command starts with an option, prepend mysqld
if [ "${1:0:1}" = '-' ]; then
	set -- mysqld "$@"
fi

# usage: file_env VAR [DEFAULT]
#    ie: file_env 'XYZ_DB_PASSWORD' 'example'
# (will allow for "$XYZ_DB_PASSWORD_FILE" to fill in the value of
#  "$XYZ_DB_PASSWORD" from a file, especially for Docker's secrets feature)
file_env() {
	local var="$1"
	local fileVar="${var}_FILE"
	local def="${2:-}"
	if [ "${!var:-}" ] && [ "${!fileVar:-}" ]; then
		echo >&2 "error: both $var and $fileVar are set (but are exclusive)"
		exit 1
	fi
	local val="$def"
	if [ "${!var:-}" ]; then
		val="${!var}"
	elif [ "${!fileVar:-}" ]; then
		val="$(< "${!fileVar}")"
	fi
	export "$var"="$val"
	unset "$fileVar"
}

_check_config() {
	toRun=( "$@" --verbose --help --log-bin-index="$(mktemp -u)" )
	if ! errors="$("${toRun[@]}" 2>&1 >/dev/null)"; then
		cat >&2 <<-EOM
			ERROR: mysqld failed while attempting to check config
			command was: "${toRun[*]}"
			$errors
		EOM
		exit 1
	fi
}

# Fetch value from server config
# We use mysqld --verbose --help instead of my_print_defaults because the
# latter only show values present in config files, and not server defaults
_get_config() {
	local conf="$1"; shift
	"$@" --verbose --help --log-bin-index="$(mktemp -u)" 2>/dev/null | awk '$1 == "'"$conf"'" { print $2; exit }'
}

# allow the container to be started with `--user`
if [ "$1" = 'mysqld' -a -z "$wantHelp" -a "$(id -u)" = '0' ]; then
	_check_config "$@"
	DATADIR="$(_get_config 'datadir' "$@")"
	mkdir -p "$DATADIR"
	chown -R mysql:mysql "$DATADIR"
	exec gosu mysql "$BASH_SOURCE" "$@"
fi




if [ "$1" = 'mysqld' -a -z "$wantHelp" ]; then
	# still need to check config, container may have started with --user
	_check_config "$@"
	# Get config
	export DATADIR="$(_get_config 'datadir' "$@")"

	if [ ! -d "$DATADIR/mysql" ]; then
	    echo 'Initializing database'
		mkdir -p "$DATADIR"
        mysql_install_db \
        --no-defaults \
        --user=mysql \
        --datadir=$DATADIR \
        --innodb-page-size=$INNODB_PAGE_SIZE \
        --skip-name-resolve \
        --cross-bootstrap

        prepare-database || exit $?
		echo 'Database initialized'
	fi
fi

CMD="$@"
if [[ ! $CMD == mysqld* ]]; then
    exec $CMD
fi


_exec_with_address() {
    echo Starting health check service
    giddyup health --check-command healthcheck.sh &
    CMD="tini -- $CMD --wsrep-cluster-address=$1";
    echo Executing $CMD
    exec $CMD

}

if [ -f "$DATADIR/grastate.dat" ] && grep "safe_to_bootstrap: 1" "$DATADIR/grastate.dat"; then
    echo "Found state file with 'safe_to_bootstrap: 1'; node is safe to bootstrap.";
#    _exec_with_address "gcomm://"
fi

# Recover from crash, don't start new cluster.
if [ -f "$DATADIR/gvwstate.dat" ]; then
    _exec_with_address "gcomm://$(giddyup ip stringify)"
fi

# We are not leader, don't start new cluster.
if [ ! -z "$norancher" ]; then
    echo "No rancher, starting new cluster."
    _exec_with_address "gcomm://";
fi

echo "Checking if we are leader...";
if giddyup leader check; then
    echo "We are leader!"
else
    echo "We are not leader!"
    _exec_with_address "gcomm://$(giddyup ip stringify)"
fi



# We are leader and scale = 1, start new cluster.
if [ "$(giddyup service scale)" -eq "1" ]; then
    echo "Scale is 1, starting new cluster."
    _exec_with_address "gcomm://";
fi

BASEURL=http://rancher-metadata/2015-12-19/self
SERVICE=$(curl $BASEURL/service/name)
STACK=$(curl $BASEURL/stack/name)

# We are leader, scale > 1.
echo "Probing for node that's alive..."
if giddyup probe -m 2s -n 10 --loop tcp://$SERVICE.$STACK:3306; then
    echo "Found alive node."
    _exec_with_address "gcomm://$(giddyup ip stringify)"
else
    echo "No node alive, launching new cluster."
    _exec_with_address "gcomm://";
fi


