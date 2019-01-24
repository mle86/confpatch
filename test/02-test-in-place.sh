#!/bin/sh
. $(dirname "$0")/init.sh


[ "$(find_assignments 'my-conf-var' '=' < "$SAMPLE_DEFAULT")" = "123" ] || skip
[ "$(find_assignments 'other-var'   '=' < "$SAMPLE_DEFAULT")" = "456" ] || skip

targetFile="$(mktemp --tmpdir="$HERE")"
hook_cleanup () { rm -f -- "$targetFile"; }
cp -- "$SAMPLE_DEFAULT" "$targetFile"

assertCmd "$PATCH -i '$targetFile' '$SAMPLES/my999.patch.ini'"

assertEq "$(find_assignments 'my-conf-var' '=' < "$targetFile")" "999" \
	"In-place editing did not work!"
assertEq "$(find_assignments 'other-var' '=' < "$targetFile")" "456" \
	"In-place editing changed wrong keys!"


success
