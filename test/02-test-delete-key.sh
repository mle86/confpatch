#!/bin/sh
. $(dirname "$0")/init.sh


sample="$SAMPLES/multi.ini"
patch="$SAMPLES/delete-key.patch.ini"

originalInput="$(cat -- "$sample")"
originalS1="$(filter_section 's1' "$originalInput")"
originalS2="$(filter_section 's2' "$originalInput")"
originalS3="$(filter_section 's3' "$originalInput")"

[ "$(find_assignments 'k1' '=' "$originalS1")" = "S1-K1" ] || skip
[ "$(find_assignments 'k1' '=' "$originalS2")" = "S2-K1" ] || skip
[ "$(find_assignments 'k2' '=' "$originalS2")" = "S2-K2" ] || skip
[ "$(find_assignments 'k1' '=' "$originalS3")" = "S3-K1" ] || skip


assertCmd "$PATCH -o - '$sample' '$patch'"
patchedS1="$(filter_section 's1' "$ASSERTCMDOUTPUT")"
patchedS2="$(filter_section 's2' "$ASSERTCMDOUTPUT")"
patchedS3="$(filter_section 's3' "$ASSERTCMDOUTPUT")"

assertEq "$(find_assignments 'k1' '=' "$patchedS2")" ""      \
	"Key deletion did not work!"
assertEq "$(find_assignments 'k2' '=' "$patchedS2")" "S2-K2" \
	"Key deletion affected other key as well!"
assertEq "$(find_assignments 'k1' '=' "$patchedS1")" "S1-K1" \
	"Key deletion had effect in other section!"
assertEq "$(find_assignments 'k1' '=' "$patchedS3")" "S3-K1" \
	"Key deletion had effect in other section!"


success
