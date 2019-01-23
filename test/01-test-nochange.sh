#!/bin/sh
. $(dirname "$0")/init.sh

originalInput="$(cat -- "$SAMPLE_DEFAULT")"
assertCmd "$PATCH -o - '$SAMPLE_DEFAULT' /dev/null"

assertEq "$ASSERTCMDOUTPUT" "$originalInput" \
	"Empty patch still changed the input!"

success
