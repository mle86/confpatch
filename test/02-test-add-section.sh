#!/bin/sh
. $(dirname "$0")/init.sh


originalInput="$(cat -- "$SAMPLE_DEFAULT")"

# The original input contains no [other section]:
[ "$(filter_section 'other section' "$originalInput")" = "" ] || skip

# But the "section" patch should append it:
assertCmd "$PATCH -o - '$SAMPLE_DEFAULT' '$SAMPLES/section.patch.ini'"

newSection="$(filter_section 'other section' "$ASSERTCMDOUTPUT")"
[ -n "$newSection" ] || fail "did not append new section"
assertEq "$(find_assignments 'qqq' '=' "$newSection")" "222" \
	"New section does not contain correct assignment(s)"
assertEq "$(find_assignments 'other-var' '=' "$newSection")" "999" \
	"New section does not contain correct assignment of key also found in other section"

oldSection="$(filter_section 'core' "$ASSERTCMDOUTPUT")"
assertEq "$(find_assignments 'other-var' '=' "$oldSection")" "456" \
	"New section appended but did also overwrite other section's same-name values!"

success
