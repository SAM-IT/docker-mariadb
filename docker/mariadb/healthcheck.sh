#!/bin/sh
mysql -u root --disable-column-names -B --execute="show global status like 'wsrep_local_state_comment'" | grep -q -v Initialized
exit $?