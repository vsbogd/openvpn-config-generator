#!/bin/sh
umask 077

config=$1
tmpdir=`mktemp -d`
tmpkey="$tmpdir/key"
tmpconf="$tmpdir/config"

cat "$config" | sed -n '/<key>/,/<\/key>/ p' \
	| tail -n +2 | head -n -1 > "$tmpkey"
openssl rsa -aes256 -in "$tmpkey" -out "$tmpkey.new"

cat "$config" | sed '/<key>/q' > "$tmpconf"
cat "$tmpkey.new" >> "$tmpconf"
cat "$config" | sed -n '/<\/key>/,$p' >> "$tmpconf"
mv "$tmpconf" "$config"

shred -u "$tmpkey" "$tmpkey.new"
rmdir "$tmpdir"
