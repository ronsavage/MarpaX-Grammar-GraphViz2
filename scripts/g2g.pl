#!/usr/bin/env perl

use strict;
use warnings;

use MarpaX::Grammar::GraphViz2;

use Getopt::Long;

use Pod::Usage;

# -----------------------------------------------

my($option_parser) = Getopt::Long::Parser -> new();

my(%option);

if ($option_parser -> getoptions
(
	\%option,
	'format=s',
	'help',
	'input_file=s',
	'maxlevel=s',
	'minlevel=s',
	'output_file=s',
	'tree_file=s',
) )
{
	pod2usage(1) if ($option{'help'});

	# Return 0 for success and 1 for failure.

	exit MarpaX::Grammar::GraphViz2 -> new(%option) -> run;
}
else
{
	pod2usage(2);
}

__END__

=pod

=head1 NAME

gem.pl - Run MarpaX::Grammar::GraphViz2 on a Marpa::R2 grammar.

=head1 SYNOPSIS

gem.pl [options]

	Options:
	-format imageFormat
	-help
	-input_file aMarpaGrammarName
	-maxlevel logOption1
	-minlevel logOption2
	-output_file aTextFileName
	-tree_file aTextFileName

Exit value: 0 for success, 1 for failure. Die upon error.

=head1 OPTIONS

=over 4

=item -format imageFormat

Specify the type of image to be created.

Default: 'svg'.

=item -help

Print help and exit.

=item -input_file aMarpaGrammarFileName

Specify the name of the file containing the Marpa::R2-style grammar.

See data/stringparser.grammar.bnf for a sample.

Default: ''.

=item -maxlevel logOption1

This option affects Log::Handler.

See the Log::handler docs.

Default: 'notice'.

=item -minlevel logOption2

This option affects Log::Handler.

See the Log::handler docs.

Default: 'error'.

No lower levels are used.

=item -output_file aTextFileName

Specify the name of a file for the renderer to write.

If '', the file is not written.

Default: ''.

=item -tree_file aTextFileName

The name of the text file to write containing the grammar as a tree.

If '', the file is not written.

Default: ''.

=back

=cut
