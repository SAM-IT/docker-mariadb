#!/bin/sh

mkdir /tmp/keys
echo "Extracting environment variables starting with PK_..."  | ts '[%Y-%m-%d %H:%M:%S]'
env | awk -F"=" '{print $1}' | grep "^PK_" | xargs -I '{}' sh -c 'echo "${}" > /tmp/keys/{}.key'
ls -l /tmp/keys  | ts '[%Y-%m-%d %H:%M:%S]'
echo "Importing keys.."  | ts '[%Y-%m-%d %H:%M:%S]'
gpg --import /tmp/keys/*  2>&1 | ts '[%Y-%m-%d %H:%M:%S]'

recipients=$(gpg --list-keys --with-colons --fast-list-mode | awk -F: '/^pub/{printf "-r %s ", $5}')
while :
do
    echo "Starting backup"  | ts '[%Y-%m-%d %H:%M:%S]';
    backup=$(date -u +"%Y%m%dT%H%M%S").gpg

    mysqldump -h $DBHOST -p$DBPASS -u $DBUSER $DBNAME | gpg --cipher-algo AES256 --compress-level 9 --always-trust $recipients --encrypt --output $backup  | ts '[%Y-%m-%d %H:%M:%S]'
    echo "Backup file created" | ts '[%Y-%m-%d %H:%M:%S]'
    ls -lah $backup | ts '[%Y-%m-%d %H:%M:%S]'
    s3cmd --host-bucket "%(bucket)s.ams3.digitaloceanspaces.com" \
      --host ams3.digitaloceanspaces.com \
      --access_key=$S3_ACCESS_KEY \
      --secret_key=$S3_SECRET_KEY \
      --acl-private \
      --no-mime-magic \
      put $backup $S3_URI \
      | ts '[%Y-%m-%d %H:%M:%S]'

    echo "Backup uploaded.." | ts '[%Y-%m-%d %H:%M:%S]'
    rm $backup
    echo "Backup finished, sleeping for $INTERVAL seconds" | ts '[%Y-%m-%d %H:%M:%S]'
    sleep $INTERVAL;
done