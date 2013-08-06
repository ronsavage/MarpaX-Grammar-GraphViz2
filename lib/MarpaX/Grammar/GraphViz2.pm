package MarpaX::Grammar::GraphViz2;

use strict;
use utf8;
use warnings;
use warnings  qw(FATAL utf8);    # Fatalize encoding glitches.
use open      qw(:std :utf8);    # Undeclared streams in UTF-8.
use charnames qw(:full :short);  # Unneeded in v5.16.

use File::Spec;

use GraphViz2;

use List::AllUtils qw/first_index indexes/;

use Moo;

use Perl6::Slurp; # For slurp().

use Tree::DAG_Node;

has format =>
(
	default  = sub{return 'sv'},
	is       = 'rw',
	#isa     = 'Str',
	required = 0,
);

has graph =>
(
	default  = sub{return ''},
	is       = 'rw',
	#isa     = 'GraphViz',
	required = 0,
);

has input_file =>
(
	default  = sub{return 'grammar.bnf'},
	is       = 'rw',
	#isa     = 'Str',
	required = 0,
);

has output_file =>
(
	default  = sub{return 'grammar.svg'},
	is       = 'rw',
	#isa     = 'Str',
	required = 0,
);

has report =>
(
	default  = sub{return ''},
	is       = 'rw',
	#isa     = 'Str',
	required = 0,
);

our $VERSION = '1.00';

# ------------------------------------------------

sub add_lexeme
{
	my($self, $start, $node, $field) = @_;
	my($parent) = $$node{$start};
	my($kid)    = Tree::DAG_Node -> new
	({
		attributes => {fillcolor => 'lightblue', shape => 'rectangle', style => 'filled'},
		name       => join(' ', shift @$field),
	});

	$parent -> add_daughter($kid);

	while (my $item = shift @$field)
	{
		$parent = $kid;
		$kid    = Tree::DAG_Node -> new
		({
			attributes => {fillcolor => 'lightblue', shape => 'rectangle', style => 'filled'},
			name       => join(' ', $item),
		});

		$parent -> add_daughter($kid);
	}

} # End of add_lexeme.

# ------------------------------------------------

sub BUILD
{
	my($self)  = @_;
	my($graph) ||= GraphViz2 -> new
		(
			edge   => {color => 'grey'},
			global => {directed => 1},
			graph  => {rankdir => 'TB'},
			logger => '',
			node   => {shape => 'oval'},
		);

	$self -> graph($graph);

} # End of BUILD.

# ------------------------------------------------

sub process_rhs
{
	my($self, $start, $node, $field, $lhs) = @_;

	my($parent);

	$$node{$start} -> walk_down
	({
		callback => sub
		{
			my($n, $options) = @_;

			$parent = $n if (! $parent && ($n -> name eq $lhs) );

			return 1;
		},
		_depth => 0,
	});

	$parent    = $$node{$start} if (! $parent);
	my($index) = first_index{$_ =~ /^action|event|pause$/} @$field;

	my($first);
	my($kid);
	my($label);
	my($rhs);

	if ($index >= 0)
	{
		$rhs                = join(' ', @$field[2 .. $index - 1]);
		substr($rhs, -1, 1) = '' if (substr($rhs, -1, 1) =~ /[?*+]/);

		if ($parent -> name ne $rhs)
		{
			$$node{$rhs} = $kid = Tree::DAG_Node -> new
			({
				attributes => {shape => 'rectangle'},
				name       => $rhs,
			});

			$parent -> add_daughter($kid);

			$parent = $kid;
		}

		my(@index) = indexes{$_ =~ /^(?:action|event|pause)/} @$field;

		if ($#index >= 0)
		{
			$label = [map{"$$field[$_] = $$field[$_ + 2]"} sort{$$field[$a] cmp $$field[$b]} @index];
			$label = '{' . join('|', @$label) . '}';

			$parent -> add_daughter
			(
				Tree::DAG_Node -> new
				({
					attributes => {fillcolor => 'lightblue', label => $label, shape => 'record', style => 'filled'},
					name       => join('/', map{$$field[$_ + 2]} @index),
				})
			);
		}
	}
	else
	{
		for (@$field[2 .. $#$field])
		{
			$rhs                = $_;
			substr($rhs, -1, 1) = '' if (substr($rhs, -1, 1) =~ /[?*+]/);

			if ($parent -> name ne $rhs)
			{
				$$node{$rhs} = $kid = Tree::DAG_Node -> new
					({
						attributes => {shape => 'rectangle'},
						name       => $rhs,
					});

				$parent -> add_daughter($kid);
			}
		}
	}

	#say '-' x 50;
	#say map{"$_\n"} @{$$node{$start} -> tree2string({no_attributes => 1})};
	#say '-' x 50;

} # End of process_rhs.

# ------------------------------------------------

sub run
{
	my($self)    = @_;
	my(@grammar) = slurp($self -> input_file, {chomp => 1});

	my(@default, @discard);
	my(@field);
	my($g_index);
	my($line, $lhs);
	my(%node);
	my($rhs);
	my($start, %seen);

	for (my $i = 0; $i <= $#grammar; $i++)
	{
		$line = $string[$i];

		next if ($line =~ /^(\s*\#|\s*$)/);

		# Convert things like [\s] to [\\s].

		$line    =~ s/\\/\\\\/g;
		@field   = split(/\s+/, $line);
		$g_index = first_index{$_ =~ /(?:~|::=)/} @field;

		# TODO:
		# o Handle in-line comments, '... # ...'.

		if ($g_index > 0)
		{
			$lhs = join(' ', @field[0 .. $g_index - 1]);

			if ($lhs eq ':default')
			{
				push @default, $lhs, "$field[2] = $field[4]";

				next;
			}
			elsif ($lhs eq ':discard')
			{
				push @discard, $lhs, $field[2];

				next;
			}
			elsif ($lhs eq ':lexeme')
			{
				$self -> process_rhs($start, \%node, \@field, $field[2]);

				next;
			}
			elsif ($lhs eq ':start')
			{
				$start        = $field[2];
				$node{$start} = Tree::DAG_Node -> new
					({
						attributes => {fillcolor => 'lightgreen', shape => 'rectangle', style => 'filled'},
						name       => $start,
					});

				next;
			}

			if ( ($#discard >= 0) && ($field[0] eq $discard[$#discard]) )
			{
				push @discard, $field[2];
			}
			else
			{
				$self -> process_rhs($start, \%node, \@field, $lhs);
			}
		}
		elsif ($field[1] =~ /^\|\|?$/)
		{
			$self -> process_rhs($start, \%node, \@field, $lhs);
		}
	}

	$self -> add_lexeme($start, \%node, \@default) if ($#default >= 0);
	$self -> add_lexeme($start, \%node, \@discard) if ($#discard >= 0);

	say map{"$_\n"} @{$node{$start} -> tree2string({no_attributes => 1})};

	$node{$start} -> walk_down
	({
		callback => sub
		{
			my($n, $options) = @_;

			# $n -> attributues returns a hashref:
			# o fillcolor => $c.
			# o label     => $l.
			# o shape     => $s.

			$graph -> add_node(name => $n -> name, %{$n -> attributes});
			$graph -> add_edge(from => $n -> mother -> name, to => $n -> name) if ($n -> mother);

			# 1 => Keep walking.

			return 1;
		},
		_depth => 0,
	});

	my($output_file) = $self -> output_file;

	$graph -> run(format => $self -> format, output_file => $output_file);

} # End of run.

# ------------------------------------------------

1;

=pod

=head1 NAME

L<MarpaX::Grammar::GraphViz2> - Convert a Marpa grammar into an image

=head1 Synopsis

=head1 Description

=head1 Installation

Install L<MarpaX::Grammar::GraphViz2> as you would for any C<Perl> module:

Run:

	cpanm MarpaX::Grammar::GraphViz2

or run:

	sudo cpan MarpaX::Grammar::GraphViz2

or unpack the distro, and then either:

	perl Build.PL
	./Build
	./Build test
	sudo ./Build install

or:

	perl Makefile.PL
	make (or dmake or nmake)
	make test
	make install

=head1 Scripts Shipped with this Module

=head1 Constructor and Initialization

C<new()> is called as C<< my($parser) = MarpaX::Grammar::GraphViz2 -> new(k1 => v1, k2 => v2, ...) >>.

It returns a new object of type C<MarpaX::Grammar::GraphViz2>.

Key-value pairs accepted in the parameter list (see corresponding methods for details
[e.g. description($graph)]):

=over 4

=item o description => '[node.1]->[node.2]'

Specify a string for the graph definition.

You are strongly encouraged to surround this string with '...' to protect it from your shell if using
this module directly from the command line.

See also the I<input_file> key which reads the graph from a file.

The I<description> key takes precedence over the I<input_file> key.

Default: ''.

=item o input_file => $graph_file_name

Read the graph definition from this file.

See also the I<description> key to read the graph from the command line.

The whole file is slurped in as a single graph.

The first lines of the file can start with /^\s*#/, and will be discarded as comments.

The I<description> key takes precedence over the I<input_file> key.

Default: ''.

=item o report_tokens => $Boolean

When set to 1, calls L</report()> to print the items recognized by the parser.

Default: 0.

=item o token_file => $file_name

The name of the CSV file in which parsed tokens are to be saved.

If '', the file is not written.

Default: ''.

=item o verbose => $integer

Prints more (1, 2) or less (0) progress messages.

Default: 0.

=back

=head1 Methods

=head1 FAQ

=head1 Machine-Readable Change Log

The file Changes was converted into Changelog.ini by L<Module::Metadata::Changes>.

=head1 Version Numbers

Version numbers < 1.00 represent development versions. From 1.00 up, they are production versions.

=head1 Support

Email the author, or log a bug on RT:

L<https://rt.cpan.org/Public/Dist/Display.html?Name=MarpaX::Grammar::GraphViz2>.

=head1 Author

L<MarpaX::Grammar::GraphViz2> was written by Ron Savage I<E<lt>ron@savage.net.auE<gt>> in 2013.

Home page: L<http://savage.net.au/>.

=head1 Copyright

Australian copyright (c) 2013, Ron Savage.

	All Programs of mine are 'OSI Certified Open Source Software';
	you can redistribute them and/or modify them under the terms of
	The Artistic License, a copy of which is available at:
	http://www.opensource.org/licenses/index.html

=cut
