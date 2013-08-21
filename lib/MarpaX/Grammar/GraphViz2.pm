package MarpaX::Grammar::GraphViz2;

use strict;
use utf8;
use warnings;
use warnings  qw(FATAL utf8);    # Fatalize encoding glitches.
use open      qw(:std :utf8);    # Undeclared streams in UTF-8.
use charnames qw(:full :short);  # Unneeded in v5.16.

use File::Basename; # For basename().
use File::Which; # For which().

use GraphViz2;

use List::AllUtils qw/first_index indexes/;

use Log::Handler;

use MarpaX::Grammar::Parser;

use Moo;

has default_count =>
(
	default  => sub{return 0},
	is       => 'rw',
	#isa     => 'int',
	required => 0,
);

has discard_count =>
(
	default  => sub{return 0},
	is       => 'rw',
	#isa     => 'int',
	required => 0,
);

has driver =>
(
	default  => sub{return ''},
	is       => 'rw',
	#isa     => 'Str',
	required => 0,
);

has format =>
(
	default  => sub{return ''},
	is       => 'rw',
	#isa     => 'Str',
	required => 0,
);

has graph =>
(
	default  => sub{return ''},
	is       => 'rw',
	#isa     => 'GraphViz',
	required => 0,
);

has logger =>
(
	default  => sub{return undef},
	is       => 'rw',
#	isa      => 'Str',
	required => 0,
);

has marpa_bnf_file =>
(
	default  => sub{return ''},
	is       => 'rw',
	#isa     => 'Str',
	required => 0,
);

has maxlevel =>
(
	default  => sub{return 'info'},
	is       => 'rw',
#	isa      => 'Str',
	required => 0,
);

has minlevel =>
(
	default  => sub{return 'error'},
	is       => 'rw',
#	isa      => 'Str',
	required => 0,
);

has parser =>
(
	default  => sub{return ''},
	is       => 'rw',
	#isa     => 'MarpaX::Grammar::Parser',
	required => 0,
);

has output_file =>
(
	default  => sub{return ''},
	is       => 'rw',
	#isa     => 'Str',
	required => 0,
);

has user_bnf_file =>
(
	default  => sub{return ''},
	is       => 'rw',
	#isa     => 'Str',
	required => 0,
);

has root_node =>
(
	default  => sub{return ''},
	is       => 'rw',
	#isa     => 'Tree::DAG_Node',
	required => 0,
);

our $VERSION = '1.00';

# ------------------------------------------------

sub BUILD
{
	my($self)  = @_;

	$self -> driver($self -> driver || which('dot') );
	$self -> format($self -> format || 'svg');

	if (! defined $self -> logger)
	{
		$self -> logger(Log::Handler -> new);
		$self -> logger -> add
		(
			screen =>
			{
				maxlevel       => $self -> maxlevel,
				message_layout => '%m',
				minlevel       => $self -> minlevel,
			}
		);
	}

	my($graph) ||= GraphViz2 -> new
		(
			edge   => {color => 'grey'},
			global => {directed => 1, driver => $self -> driver, format => $self -> format},
			graph  => {label => basename($self -> user_bnf_file), rankdir => 'TB'},
			logger => $self -> logger,
			node   => {shape => 'rectangle', style => 'filled'},
		);

	$self -> graph($graph);

	$self -> parser
	(
		MarpaX::Grammar::Parser -> new
		(
			marpa_bnf_file => $self -> marpa_bnf_file,
			logger         => $self -> logger,
			user_bnf_file  => $self -> user_bnf_file,
		)
	);

} # End of BUILD.

# --------------------------------------------------

sub log
{
	my($self, $level, $s) = @_;

	$self -> logger -> log($level => $s) if ($self -> logger);

} # End of log.

# --------------------------------------------------

sub process_default_rule
{
	my($self, $index, $a_node) = @_;

	$self -> default_count($self -> default_count + 1);

	my($default_count) = $self -> default_count;
	my($default_name)  = ':default';
	my($attributes)    =
	{
		fillcolor => 'lightblue',
		label     => $default_name,
	};

	if ($default_count == 1)
	{
		$self -> graph -> add_node(name => $default_name, %$attributes);
		$self -> graph -> add_edge(from => $self -> root_node -> name, to => $default_name);
	}

	my(@daughters) = $a_node -> daughters;
	my($name)      = "${default_name}_$default_count";

	my(@label);

	# Ignore the first daughter, which is '::='.

	for (my $i = 1; $i < $#daughters; $i += 3)
	{
		push @label, {text => join(' ', map{$daughters[$_] -> name} $i .. $i + 2)};

		$label[$#label]{text} =~ s/>/\\>/;
	}

	$label[$#label]{text} .= '}';
	$$attributes{label}   = [@label],

	$self -> graph -> add_node(name => $name, %$attributes);
	$self -> graph -> add_edge(from => $default_name, to => $name);

} # End of process_default_rule.

# --------------------------------------------------

sub process_discard_rule
{
	my($self, $index, $a_node) = @_;

	$self -> discard_count($self -> discard_count + 1);

	my($discard_count) = $self -> discard_count;
	my($discard_name)  = ':discard';
	my($attributes)    =
	{
		fillcolor => 'lightblue',
		label     => $discard_name,
	};

	if ($discard_count == 1)
	{
		$self -> graph -> add_node(name => $discard_name, %$attributes);
		$self -> graph -> add_edge(from => $self -> root_node -> name, to => $discard_name);
	}

	# Ignore the first daughter, which is '=>'.

	my(@daughters)      = $a_node -> daughters;
	my($name)           = $daughters[1] -> name;
	$name               =~ s/>/\\>/;
	$$attributes{label} = $name;

	$self -> graph -> add_node(name => $name, %$attributes);
	$self -> graph -> add_edge(from => $discard_name, to => $name);

} # End of process_discard_rule.

# --------------------------------------------------

sub process_rule
{
	my($self, $index, $a_node) = @_;
	my($name)       = $a_node -> name;
	my($attributes) =
	{
		fillcolor => 'white',
		label     => $name,
	};

	$self -> graph -> add_node(name => $name, %$attributes);

} # End of process_rule.

# --------------------------------------------------

sub process_start_rule
{
	my($self, $index, $a_node) = @_;
	my($start_name) = $a_node -> name;
	my(@daughters)   = $a_node -> daughters;
	my($name)        = $daughters[1] -> name;
	my($attributes)  =
	{
		fillcolor => 'lightgreen',
		label     => [{text => "{$start_name"}, {text => "$name}"}],
	};

	$self -> graph -> add_node(name => $name, %$attributes);
	$self -> root_node($daughters[1]);

} # End of process_start_rule.

# ------------------------------------------------

sub run
{
	my($self)   = @_;
	my($result) = $self -> parser -> run;

	if ($result == 0)
	{
		my(@rule) = $self -> parser -> cooked_tree -> daughters;

		# Phase 1: Process the :start rule.

		my($start_index) = first_index{$_ -> name eq ':start'} @rule;

		$self -> process_start_rule($start_index + 1, $rule[$start_index]);

		# Phase 2: Process the :default rules.

		for my $index (indexes {$_ -> name eq ':default'} @rule)
		{
			$self -> process_default_rule($index + 1, $rule[$index]);
		}

		# Phase 3: Process the :discard rules.

		for my $index (indexes {$_ -> name eq ':discard'} @rule)
		{
			$self -> process_discard_rule($index + 1, $rule[$index]);
		}

		# Phase 8: Process the other rules.

		for my $index (0 .. $#rule)
		{
#			next if ($index == $start_index);

#			$self -> process_rule($index + 1, $rule[$index]);
		}

		my($output_file) = $self -> output_file;

		$self -> graph -> run(output_file => $output_file);
	}

	# Return 0 for success and 1 for failure.

	return $result;

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
[e.g. logger([$string])]):

=over 4

=item o format => $format_name

This is the format of the output file, to be created by the renderer.

The value for I<format> is passed to L<Graph::Easy::Marpa::Renderer::GraphViz2>.

Default: 'svg'.

=item o graph => $graphviz2_object

Provides an object of type L<GraphViz2>, to do the rendering.

If '', the image is not rendered. And, even if provided, if C<output_file> is not provided, the image
is not generated.

Default:

	my($graph) ||= GraphViz2 -> new
		(
			edge   => {color => 'grey'},
			global => {directed => 1},
			graph  => {rankdir => 'TB'},
			logger => '',
			node   => {shape => 'oval'},
		);

Set to '' to disable rendering.

=item o input_file => $grammar_file_name

Read the grammar definition from this file.

The whole file is slurped in as a single string.

The parameter is mandatory.

See data/stringparser.grammar.bnf for a sample.

Default: ''.

=item o logger => $logger_object

Specify a logger object.

The default value triggers creation of an object of type L<Log::Handler> which outputs to the screen.

To disable logging, just set I<logger> to the empty string.

The value for I<logger> is passed to L<Graph::Easy::Marpa::Parser> and to L<Graph::Easy::Marpa::Renderer::GraphViz2>.

Default: undef.

=item o maxlevel => $level

This option is only used if an object of type L<Log::Handler> is created. See I<logger> above.

See also L<Log::Handler::Levels>.

The value for I<maxlevel> is passed to L<Graph::Easy::Marpa::Parser> and to L<Graph::Easy::Marpa::Renderer::GraphViz2>.

Default: 'info'. A typical value is 'debug'.

=item o minlevel => $level

This option is only used if an object of type L<Log::Handler> is created. See I<logger> above.

See also L<Log::Handler::Levels>.

The value for I<minlevel> is passed to L<Graph::Easy::Marpa::Parser> and to L<Graph::Easy::Marpa::Renderer::GraphViz2>.

Default: 'error'.

No lower levels are used.

==item o output_file => $output_file_name

Write the image to this file.

If '', the file is not written. And even if provided, if C<graph> is '', the image is not rendered.

Default: ''.

=item o tree_file => $file_name

The name of the text file to write containing the grammar as a tree.

The output is generated by L<Tree::DAG_Node>'s C<tree2string()> method.

If '', the file is not written.

Default: ''.

=back

=head1 Installing the module

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
	make (or dmake)
	make test
	make install

=head1 Methods

=head2 format([$format])

Here, the [] indicate an optional parameter.

Get or set the format of the output file, to be created by the renderer.

Note: C<format> is a parameter to new().

=head2 graph([$graph])

Get of set the L<GraphViz2> object which will do the graphing.

The default object is:

	my($graph) ||= GraphViz2 -> new
		(
			edge   => {color => 'grey'},
			global => {directed => 1},
			graph  => {rankdir => 'TB'},
			logger => '',
			node   => {shape => 'oval'},
		);

Set to '' to disable rendering.

See also L</output_file([$output_file_name])>.

Note: C<graph> is a parameter to new().

=head2 input_file([$graph_file_name])

Here, the [] indicate an optional parameter.

Get or set the name of the file to read the grammar definition from.

The whole file is slurped in as a single string.

The parameter is mandatory.

See data/stringparser.grammar.bnf for a sample.

Note: C<input_file> is a parameter to new().

=head2 log($level, $s)

Calls $self -> logger -> log($level => $s) if ($self -> logger).

=head2 logger([$logger_object])

Here, the [] indicate an optional parameter.

Get or set the logger object.

To disable logging, just set logger to the empty string.

This logger is passed to L<Graph::Easy::Marpa::Parser> and L<Graph::Easy::Marpa::Renderer::GraphViz2>.

Note: C<logger> is a parameter to new().

=head2 maxlevel([$string])

Here, the [] indicate an optional parameter.

Get or set the value used by the logger object.

This option is only used if an object of type L<Log::Handler> is created. See L<Log::Handler::Levels>.

Note: C<maxlevel> is a parameter to new().

=head2 minlevel([$string])

Here, the [] indicate an optional parameter.

Get or set the value used by the logger object.

This option is only used if an object of type L<Log::Handler> is created. See L<Log::Handler::Levels>.

Note: C<minlevel> is a parameter to new().

=head2 output_file([$output_file_name])

Here, the [] indicate an optional parameter.

Get or set the name of the file to which the renderer will write to resultant graph.

If no output file is supplied, nothing is written.

See also L<graph([$graph])>.

Note: C<output_file> is a parameter to new().

=head2 tree_file([$output_file_name])

Here, the [] indicate an optional parameter.

Get or set the name of the file to which the tree form of the graph will be written.

If no output file is supplied, nothing is written.

Note: C<tree_file> is a parameter to new().

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
