#!/bin/sh
. $(dirname "$0")/init.sh


[ "$(find_assignments 'my-conf-var' '=' < "$SAMPLE_DEFAULT")" = "123" ] || skip
[ "$(find_assignments 'other-var'   '=' < "$SAMPLE_DEFAULT")" = "456" ] || skip
originalChecksum="$(checksum "$SAMPLE_DEFAULT")"

targetFile="$(mktemp --tmpdir="$HERE")"  # exists now but is empty
hook_cleanup () { rm -f -- "$targetFile"; }

assertCmd "$PATCH -o '$targetFile' '$SAMPLE_DEFAULT' '$SAMPLES/my999.patch.ini'"


assertEq "$(find_assignments 'my-conf-var' '=' < "$SAMPLE_DEFAULT")" "123" \
	"'confpatch -o FILE' changed original file!"
assertEq "$(find_assignments 'other-var'   '=' < "$SAMPLE_DEFAULT")" "456" \
	"'confpatch -o FILE' changed original file!"
assertEq "$(checksum "$SAMPLE_DEFAULT")" "$originalChecksum" \
	"'confpatch -o FILE' changed original file!"

assertEq "$(find_assignments 'my-conf-var' '=' < "$targetFile")" "999" \
	"Editing with '-o FILE' output did not work!"
assertEq "$(find_assignments 'other-var' '=' < "$targetFile")" "456" \
	"Editing with '-o FILE' output changed wrong keys!"


success
