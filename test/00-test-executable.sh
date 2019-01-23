#!/bin/sh
. $(dirname "$0")/init.sh

assertCmd "$PATCH -o - /dev/null /dev/null"
assertEmpty "$ASSERTCMDOUTPUT"

success
