#!/usr/bin/perl
use Getopt::Long qw(:config no_getopt_compat bundling);
use Scalar::Util qw(openhandle);
use warnings;
use strict;
require 'dumpvar.pl';


## Defaults:  ##################################################################

use constant {
	DEFAULT_COMMENT_CHAR => '#',
	DEFAULT_ASSIGN_CHAR => '=',
};

sub Syntax {
	my ($M1, $M0, $Mu) = ('[1m', '[0m', '[4m');
	printf STDERR <<EOT, $0, DEFAULT_COMMENT_CHAR, DEFAULT_ASSIGN_CHAR;
syntax: %s {${M1}-i${M0}|${M1}-o${M0} ${Mu}FILE${M0}} [${Mu}OPTIONS${M0}] ${Mu}INPUTFILE${M0} ${Mu}PATCHFILE${M0}
options:
  ${M1}-i${M0}|${M1}--in-place${M0}              Edit the ${Mu}INPUTFILE${M0} in-place.
  ${M1}-o${M0}|${M1}--output-file${M0} ${Mu}FILENAME${M0}  Write the patched config to ${Mu}FILENAME${M0},
                             don't change ${Mu}INPUTFILE${M0}.
  ${M1}-c${M0}|${M1}--comment-char${M0} ${Mu}C${M0}        Line comment prefix.  Default: ${M1}%s${M0}
  ${M1}-g${M0}|${M1}--assign-char${M0} ${Mu}C${M0}         Key-value assignment character.  Default: ${M1}%s${M0}
  ${M1}-d${M0}|${M1}--default-section${M0} ${Mu}NAME${M0}  Default section name for settings without section.
  ${M1}-D${M0}|${M1}--no-default-section${M0}    Fail on settings with section.

EOT
	exit($_[0] // 0);
}


## Read settings:  #############################################################

my $inPlace;
my $outputFile;
my $commentChar = DEFAULT_COMMENT_CHAR;
my $assignChar = DEFAULT_ASSIGN_CHAR;
my $defaultSection = undef;

GetOptions(
	'i|in-place'      => sub{ $inPlace = 1; undef $outputFile; },
	'o|output-file=s' => sub{ $inPlace = 0; $outputFile = $_[1]; },
	'c|comment-char=s' => sub{ $commentChar = $_[1]; },
	'g|assign-char=s' => sub{ $assignChar = $_[1]; },
	'd|default-section=s' => sub{ $defaultSection = $_[1]; },
	'D|no-default-section' => sub{ undef $defaultSection; },
	'h|help' => sub { Syntax(); },
);

if ((!$inPlace && !defined $outputFile) || ($inPlace && defined $outputFile)) {
	printf STDERR "Need either option -i or -o\n";
	exit 1;
}

my $inputFile = $ARGV[0];
if (!defined $inputFile) {
	printf STDERR "No INPUTFILE\n";
	exit 1;
}

my $patchFile = $ARGV[1];
if (!defined $patchFile) {
	printf STDERR "No PATCHFILE\n";
	exit 1;
}

if ($inPlace) {
	$outputFile = $inputFile;
}


## Prepare matching:  ###########################################################

my $re_commentline = qr/^\s*${commentChar}/;
my $re_blankline = qr/^\s*$/;
my $re_section = qr/^\s*\[(?<sec>[^\]]*)\]\s*(?:${commentChar}.*)?$/;
my $re_assign = qr/^(?<vk>\s*(?!$commentChar)(?<k>\S[^$assignChar]*?)\s*)${assignChar}(?<vv>.*)$/;
my $re_assigncomment = qr/^\s*${commentChar}\s*(?<k>\S[^$assignChar]*?)\s*${assignChar}/;


## Read patch input:  ###########################################################

sub read_patch_file {
	my ($filename) = @_;
	my %patch;
	my $comment;
	my $section;

	open PFH, "< $filename" or die "could not open patch file $filename: $!";
	while (defined($_ = <PFH>)) {

		if (m/$re_commentline/) {
			$comment .= $_;
			next;
		}

#		if (m/^(\s*(\S[^$assignChar]*?)\s*)${assignChar}(.*)$/) {
		if (m/$re_assign/) {
			my ($verbatimKey, $key, $verbatimValue) = ($+{'vk'}, $+{'k'}, $+{'vv'});
			push @{ $patch{$section} }, {
				key => $key,
				verbatimKey => $verbatimKey,
				verbatimValue => $verbatimValue,
				comment => $comment,
			};
			undef $comment;
			next;
		}

		# anything else clears the comment:
		undef $comment;

		next if m/$re_blankline/;  # ignore blank lines

#		if (m/^\s*\[([^\]]*)\]\s*(?:${commentChar}.*)?$/) {
		if (m/$re_section/) {
			$section = $+{'sec'};
			next;
		}

		printf STDERR "$filename:$.: malformed line ($_)\n";
	}
	close PFH;
	return %patch;
}

# ( section => [ {key, verbatimKey, verbatimValue, comment}, ... ], ... )
my %patch = read_patch_file($patchFile);

# ( section => [ key, ... ], ... )
my %applied = ();


## Read and prepare source file:  ##############################################

open IN, "< ${inputFile}"
	or die "could not open '$inputFile' for reading: $!";
my @input = <IN>;
close IN;

# This var contains a list of all keys explicitly assigned in the input.
# (section => [key, ...], ...)
my %explicitAssignments = find_assignments(\@input, $re_assign);
# This var contains a list of all keys with a commented-out assignment in the input.
# (section => [key, ...], ...)
my %commentedAssignments = find_assignments(\@input, $re_assigncomment);

sub find_assignments {
	my ($input, $re) = @_;
	my $section;
	my %list = ();
	foreach (@$input) {
		if (m/$re_section/) { $section = $+{'sec'}; }
		elsif (m/$re/) { push @{ $list{$section} }, $+{'k'}; }
	}
	return %list;
}

sub is_assigned_explicitly ($$) {
	my ($section, $key) = @_;
	exists($explicitAssignments{$section}) && grep { $_ eq $key } @{ $explicitAssignments{$section} }
}

sub is_assigned_in_comment ($$) {
	my ($section, $key) = @_;
	exists($commentedAssignments{$section}) && grep { $_ eq $key } @{ $commentedAssignments{$section} }
}

sub is_applied ($$) {
	my ($section, $key) = @_;
	exists($applied{$section}) && grep { $_ eq $key } @{ $applied{$section} }
}


## Process and patch source file:  #############################################

# If outputFile is "-", the patch function can simply print to STDOUT.
# But if outputFile is a real filename, the patch function must write to $output
# because we may be doing an in-place edit which would mess up our input.
my $outputBuffer;
if ($outputFile ne '-') {
	$outputBuffer = '';
	open OUT, '>', \$outputBuffer;
	select OUT;
}

my $currentSection;
my $currentKey;
patch_input(\@input, \%patch);
select STDOUT;

sub assign {
	my %a = @_;
	push @{$applied{$currentSection}}, $a{'key'};

	($a{'comment'} // '') .
	($a{'verbatimKey'} // $a{'key'}) .
	$assignChar .
	($a{'verbatimValue'} // $a{'value'}) .
	"\n"
}

sub process_section_change {
	my $section = $_[0] // $currentSection;

	# We just encountered a section change.
	# If our patch contains some assignments for the current section
	# that haven't been applied yet, print them now:
	
	my @openAssignments = grep {
			my $k = $_->{'key'};
			! is_assigned_explicitly($section, $k) &&
			! is_assigned_in_comment($section, $k) &&
			! is_applied($section, $k)
		} @{$patch{$section}};

	return if ! @openAssignments;

	print "\n";
	if (!defined $currentSection || $section ne $currentSection) {
		$currentSection = $section;
		print "[$section]\n";
	}
	print assign %$_ foreach @openAssignments;
	print "\n";
}

sub process_key_change {
	# We just encountered a key change.
	# So if the main loop remembered a key (from commented-out assignments),
	# see if we can now attach our correct assignment:

	my ($assignment) = (grep { $_->{'key'} eq $currentKey } @{$patch{$currentSection}});
	return if ! defined $assignment;  # the patch says nothing about this key

	print assign(%$assignment);
	undef $currentKey;
}

sub find_assignment {
	my ($section, $key) = @_;
	return ( grep { $_->{'key'} eq $key } @{$patch{$section}} )[0];
}

sub patch_input {
	my ($input, $patch) = @_;

	foreach (@$input) {
		if (m/$re_assign/) {
			process_key_change() if (defined $currentKey && 1);#$currentKey ne $+{'k'});
			# Explicit assignment for some key.
			# Make sure it's the correct value:
			my $targetAssignment = find_assignment($currentSection, $+{'k'});
			if (! defined $targetAssignment || $targetAssignment->{'verbatimValue'} eq $+{'vv'}) {
				# Okay, leave it unchanged.
				print;
			} else {
				# Comment-out the existing line, print replacement afterwards:
				print $commentChar . $_;
				print assign(%$targetAssignment);
			}

		} elsif (m/$re_assigncomment/ && !is_assigned_explicitly($currentSection, $+{'k'})) {
			# Commented-out assignment for some key
			# and the input has no explicit assignment for that value --
			# append our own assignment afterwards:
			$currentKey = $+{'k'};
			print;

		} elsif (m/$re_section/) {
			process_key_change() if defined $currentKey;
			process_section_change() if defined $currentSection;
			$currentSection = $+{'sec'};
			print;

		} else {
			process_key_change() if defined $currentKey;
			print;
		}
	}

	# eof
	process_key_change() if defined $currentKey;
	process_section_change() if defined $currentSection;
	process_section_change($_) foreach keys %patch;
}



if (defined $outputBuffer) {
	# patch_input() wrote something into this var.
	# Print it all at once into the output file:
	open OUT, "> ${outputFile}"
		or die "could not open '$outputFile' for writing: $!";
	print OUT $outputBuffer;
	close OUT;
} else {
	# patch_input() probably wrote to STDOUT directly.
}

exit;

