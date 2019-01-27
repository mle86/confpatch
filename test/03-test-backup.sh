#!/bin/sh
. $(dirname "$0")/init.sh


[ "$(find_assignments 'my-conf-var' '=' < "$SAMPLE_DEFAULT")" = "123" ] || skip
[ "$(find_assignments 'other-var'   '=' < "$SAMPLE_DEFAULT")" = "456" ] || skip

targetFile="$(mktemp --tmpdir="$HERE")"
backupFile="${targetFile}~"
hook_cleanup () { rm -f -- "$targetFile" "$backupFile"; }
[ ! -e "$backupFile" ] || fail "Backup file '$backupFile' already exists!?"
cp -- "$SAMPLE_DEFAULT" "$targetFile"


assertCmd "$PATCH -b -i '$targetFile' '$SAMPLES/my999.patch.ini'"

[ -e "$backupFile" ] || fail "'confpatch -bi' did not write a backup file!"
[ -s "$backupFile" ] || fail "'confpatch -bi' wrote an empty backup file!"

assertEq "$(find_assignments 'my-conf-var' '=' < "$targetFile")" "999" \
	"In-place editing with '-b' did not work!"
assertEq "$(find_assignments 'other-var' '=' < "$targetFile")" "456" \
	"In-place editing with '-b' changed wrong keys!"

diff -q -- "$backupFile" "$SAMPLE_DEFAULT" >/dev/null || fail \
	"'confpatch -bi' changed backup file too!"

# TODO: test confpatch -bo


success
