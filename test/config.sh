#!/bin/sh

PATCH="$HERE/../confpatch.pl"

SAMPLES="$HERE/samples/"
SAMPLE_DEFAULT="$SAMPLES/default.ini"


# contains STRING FRAGMENT
#  True if STRING contains the string FRAGMENT somewhere.
contains () {
	local string="$1"
	local fragment="$2"
	case "$string" in
		*"$fragment"*) return 0 ;;
		*) return 1 ;;
	esac
}

# matches STRING REGEX
#  True if the STRING matches the REGEX.
#  The regex argument must be enclosed by slashes,
#  can start with a '!' to negate the matching sense,
#  and can end with i/m/s modifier(s).
matches () {
	local string="$1"
	local _regex="$2"
	local inverse=
	local modifiers=

	local regex="${_regex#!}"
	[ "$regex" != "$_regex" ] && inverse="!"

	local modifiers="${regex##*/}"
	case "$modifiers" in
		*[!ism]*)
			printf "Illegal regex modifiers: /%s\n" "$modifiers" >&2
			return 1
			;;
	esac

	regex="${regex#/}"
	regex="${regex%/*}"

	perl -e "(\$_, \$regex) = @ARGV; exit ! $inverse m/\$regex/$modifiers" "$string" "$regex"
}

# find_assignments KEY ASSIGNCHAR [STRING=<stdin>]
find_assignments () {
	local key="$1"
	local char="$2"
	local string=
	if [ "$#" -ge 3 ]; then
		string="$3"
	else
		string="$(cat)"
	fi

	perl -e '
		my ($key, $char, $s) = @ARGV;
		while ($s =~ m/^\s*$key\s*$char[^\S\r\n]*+(.*)$/gm) {
			print ($1 ne "" ? $1 : "EMPTY");
			print "\n";
		}' \
		"$key" "$char" "$string"
}

# count_assignments KEY ASSIGNCHAR [STRING=<stdin>]
count_assignments () {
	find_assignments "$@" | wc -l
}

# filter_section SECTION [INPUT=<stdin>]
filter_section () {
	local section="$1"
	local input=
	if [ "$#" -ge 2 ]; then
		input="$2"
	else
		input="$(cat)"
	fi

	perl -e '
		my ($section, $input) = @ARGV;
		print "$1\n" while ($input =~ m/^\s*\[$section\][^\r\n]*\n(.*?)(?:^\s*\[|\Z)/smg);
		' "$section" "$input"
}

checksum () {
	md5sum -b "$1" | cut -d' ' -f1
}

