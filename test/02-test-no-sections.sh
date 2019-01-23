#!/bin/sh
. $(dirname "$0")/init.sh


sampleFile="$SAMPLES/no-section.ini"
patchFile="$SAMPLES/no-section.patch.ini"
assertCmd "$PATCH -o - '$sampleFile' '$patchFile'"

assertEq "$(find_assignments 'k2' '=' "$ASSERTCMDOUTPUT")" "v2" \
	"No-section patch changed other values!"
assertEq "$(find_assignments 'k3' '=' "$ASSERTCMDOUTPUT")" "PATCHED-333" \
	"No-section patch did not correctly change values!"
assertEq "$(find_assignments 'k4' '=' "$ASSERTCMDOUTPUT")" "PATCHED-444" \
	"No-section patch did not correctly add values!"

success

