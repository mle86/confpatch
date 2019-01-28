#!/bin/sh
. $(dirname "$0")/init.sh


[ "$(find_assignments 'my-conf-var' '=' < "$SAMPLE_DEFAULT")" = "123" ] || skip
[ "$(find_assignments 'other-var'   '=' < "$SAMPLE_DEFAULT")" = "456" ] || skip

targetFile="$(mktemp --tmpdir="$HERE")"
backupFile="${targetFile}~"
hook_cleanup () { rm -f -- "$targetFile" "$backupFile"; }
[ ! -e "$backupFile" ] || fail "Backup file '$backupFile' already exists!?"
cp -- "$SAMPLE_DEFAULT" "$targetFile"


## Test -bi (backup when patching existing file in-place)

assertCmd "$PATCH -b -i '$targetFile' '$SAMPLES/my999.patch.ini'"

[ -e "$backupFile" ] || fail "'confpatch -bi' did not write a backup file!"
[ -s "$backupFile" ] || fail "'confpatch -bi' wrote an empty backup file!"

assertEq "$(find_assignments 'my-conf-var' '=' < "$targetFile")" "999" \
	"In-place editing with '-b' did not work!"
assertEq "$(find_assignments 'other-var' '=' < "$targetFile")" "456" \
	"In-place editing with '-b' changed wrong keys!"

diff -q -- "$backupFile" "$SAMPLE_DEFAULT" >/dev/null || fail \
	"'confpatch -bi' changed backup file too!"

rm -- "$backupFile"

# Now that the patch has been applied, we can safely re-apply it.
# That should NOT create a new backup because we didn't change anything.

patchedChecksum="$(checksum "$targetFile")"
assertCmd "$PATCH -b -i '$targetFile' /dev/null"
assertEq "$(checksum "$targetFile")" "$patchedChecksum" \
	"Applying an empty patch changed something!"
[ ! -e "$backupFile" ] || fail "Applying an empty patch created a backup file!"

assertCmd "$PATCH -b -i '$targetFile' '$SAMPLES/my999.patch.ini'"
assertEq "$(checksum "$targetFile")" "$patchedChecksum" \
	"Applying the same patch a second time changed something again!"
[ ! -e "$backupFile" ] || fail "Applying the same patch a second time created a backup file!"


## Test -bo (backup when writing into possibly-existing output file)

# TODO: test confpatch -bo


success
