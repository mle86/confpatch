#!/bin/sh
. $(dirname "$0")/init.sh


originalInput="$(cat -- "$SAMPLE_DEFAULT")"

# The original input contains exactly one 'my-conf-var' assignment:
[ "$(count_assignments 'my-conf-var' '=' "$originalInput")" -eq 1 ] || skip
# The original my-key-value is NOT 999:
[ "$(find_assignments 'my-conf-var' '=' "$originalInput")" = "123" ] || skip
# The original input contains no 'my-added-var' assignment:
[ "$(count_assignments 'my-added-var' '=' "$originalInput")" -eq 0 ] || skip


# After the "my999" patch, 'my-conf-var' should be set to 999 and to 999 only:
assertCmd "$PATCH -o - '$SAMPLE_DEFAULT' '$SAMPLES/my999.patch.ini'"
assertEq    "$(find_assignments 'my-conf-var' '=' "$ASSERTCMDOUTPUT")" "999"
assertEmpty "$(find_assignments 'my-added-var' '=' "$ASSERTCMDOUTPUT")"

# After the "add888" patch, there should be one 'my-added-var=888' assignment:
assertCmd "$PATCH -o - '$SAMPLE_DEFAULT' '$SAMPLES/add888.patch.ini'"
assertEq    "$(find_assignments 'my-conf-var' '=' "$ASSERTCMDOUTPUT")" "123"
assertEq    "$(find_assignments 'my-added-var' '=' "$ASSERTCMDOUTPUT")" "888"

success
