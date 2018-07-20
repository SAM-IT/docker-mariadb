#!/bin/sh

tmpfile=$(mktemp -t keyring.XXXXXX);

# Open handle
exec 3>"$tmpfile"
# Remove file
rm $tmpfile

gpg=gpg --always-trust --no-default-keyring --keyring $tmpfile

$gpg --import