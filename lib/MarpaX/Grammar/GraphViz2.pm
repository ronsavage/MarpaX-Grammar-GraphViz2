package MarpaX::Grammar::GraphViz2;

use strict;
use utf8;
use warnings;
use warnings  qw(FATAL utf8);    # Fatalize encoding glitches.
use open      qw(:std :utf8);    # Undeclared streams in UTF-8.
use charnames qw(:full :short);  # Unneeded in v5.16.

use File::Basename; # For basename().
use File::Spec;

use GraphViz2;

use List::AllUtils qw/first_index indexes/;

use Log::Handler;

use Moo;

use Perl6::Slurp; # For slurp().

use Tree::DAG_Node;

has adverbs =>
(
	default  => sub{return ''},
	is       => 'rw',
	#isa     => 'Str',
	required => 0,
);

has format =>
(
	default  => sub{return 'svg'},
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

has input_file =>
(
	default  => sub{return 'grammar.bnf'},
	is       => 'rw',
	#isa     => 'Str',
	required => 0,
);

has logger =>
(
	default  => sub{return undef},
	is       => 'rw',
#	isa      => 'Str',
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

has output_file =>
(
	default  => sub{return 'grammar.svg'},
	is       => 'rw',
	#isa     => 'Str',
	required => 0,
);

has tree_file =>
(
	default  => sub{return ''},
	is       => 'rw',
	#isa     => 'Str',
	required => 0,
);

our $VERSION = '1.00';

# ------------------------------------------------

sub add_lexeme
{
	my($self, $start, $node, $field) = @_;
	my($parent) = $$node{$start};
	my($name)   = join(' ', shift @$field);
	my($kid)    = Tree::DAG_Node -> new
	({
		attributes => {fillcolor => 'lightblue', label => $name, shape => 'rectangle', style => 'filled'},
		name       => $name,
	});

	$parent -> add_daughter($kid);

	my($label)              = [map{ {text => $_} } @$field];
	$$label[0]{text}        = "{$$label[0]{text}";
	$$label[$#$label]{text} = "$$label[$#$label]{text}\}";
	$parent                 = $kid;
	$kid                    = Tree::DAG_Node -> new
	({
		attributes => {fillcolor => 'lightblue', label => $label, shape => 'record', style => 'filled'},
		name       => join('|', map{$$_{text} } @$label),
	});

	$parent -> add_daughter($kid);

} # End of add_lexeme.

# ------------------------------------------------

sub add_adverb_record
{
	my($self, $parent, $field) = @_;
	my($adverbs) = $self -> adverbs;
	my(@index)   = indexes{$_ =~ /^(?:$adverbs)/} @$field;

	if ($#index >= 0)
	{
		my($label)              = [map{ {text => "$$field[$_] = $$field[$_ + 2]"} } sort{$$field[$a] cmp $$field[$b]} @index];
		$$label[0]{text}        = "{$$label[0]{text}";
		$$label[$#$label]{text} = "$$label[$#$label]{text}}";

		$parent -> add_daughter
		(
			Tree::DAG_Node -> new
			({
				attributes => {fillcolor => 'lightblue', label => $label, shape => 'record', style => 'filled'},
				name       => join('|', map{$$_{text} } @$label),
			})
		);
	}

} # End of add_adverb_record.

# ------------------------------------------------

sub add_event_record
{
	my($self, $parent, $field) = @_;
	my($label) = '{' . join('|', @$field) . '}';

	$parent -> add_daughter
	(
		Tree::DAG_Node -> new
		({
			attributes => {fillcolor => 'lightblue', label => $label, shape => 'record', style => 'filled'},
			name       => $label,
		})
	);

} # End of add_adverb_record.

# ------------------------------------------------

sub BUILD
{
	my($self)  = @_;

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
			global => {directed => 1},
			graph  => {label => basename($self -> input_file), rankdir => 'TB'},
			logger => $self -> logger,
			node   => {shape => 'oval'},
		);

	$self -> graph($graph);

	my(%adverbs) =
	(
		action    => 1,
		assoc     => 1,
		bless     => 1,
		event     => 1,
		pause     => 1,
		priority  => 1,
		proper    => 1,
		rank      => 1,
		separator => 1,
	);

	$self -> adverbs(join('|', sort keys %adverbs) );

} # End of BUILD.

# --------------------------------------------------

sub clean_up_angle_brackets
{
	my($self, $field) = @_;
	my($index) = first_index{$_ =~ /^</} @$field;

	while ($index >= 0)
	{
		# Steps:
		# o Replace '<' and '>' with chevrons.
		# o Combine '<x' 'y>' into '<x_y>' (but with '_' replaced by a superscript '_').
		#	Note: This takes place even for '<A>'. Hence $i = $index and not $i = $index + 1.

		for (my $i = $index; $i <= $#$field; $i++)
		{
			if ($$field[$i] =~ />$/)
			{
				splice(@$field, $index, ($i - $index + 1), join("\x{00AF}", @$field[$index .. $i]) );

				substr($$field[$index], 0,   1) = "\x{00AB}"; # <<.
				substr($$field[$index], - 1, 1) = "\x{00BB}"; # >>.

				# Keep searching for '<x' 'y>'.

				$index = first_index{$_ =~ /^</ && $_ !~ />$/} @$field;

				last;
			}
		}
	}

} # End of clean_up_angle_brackets.

# --------------------------------------------------

sub log
{
	my($self, $level, $s) = @_;

	$self -> logger -> log($level => $s) if ($self -> logger);

} # End of log.

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

	$parent      = $$node{$start} if (! $parent);
	my($adverbs) = $self -> adverbs;
	my($index)   = first_index{$_ =~ /^$adverbs$/} @$field;

	my($kid);
	my($rhs);

	if ($index >= 0)
	{
		$rhs                = join(' ', @$field[2 .. $index - 1]);
		substr($rhs, -1, 1) = '' if (substr($rhs, -1, 1) =~ /[?*+]/);

		if ($parent -> name ne $rhs)
		{
			$$node{$rhs} = $kid = Tree::DAG_Node -> new
			({
				attributes => {fillcolor => 'white', label => $rhs, shape => 'rectangle', style => ''},
				name       => $rhs,
			});

			$parent -> add_daughter($kid);

			$parent = $kid;
		}

		$self -> add_adverb_record($parent, $field);
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
						attributes => {fillcolor => 'white', label => $rhs, shape => 'rectangle', style => ''},
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

	$self -> log(info => 'Entered run()');

	my(@default, @discard);
	my(@event);
	my(@field);
	my($g_index);
	my($line, $lhs, @lexeme_default);
	my(%node);
	my($rhs);
	my($start, %seen);

	for (my $i = 0; $i <= $#grammar; $i++)
	{
		$line = $grammar[$i];

		next if ($line =~ /^(\s*\#|\s*$)/);

		# Clean up input line:
		# o Squash multiple spaces into 1 and tabs into 1 space.
		# o Convert things like [\s] to [\\s].
		# o Remove leading spaces.
		# o Replace '<a' 'b>' with '<<a b>>'
		#
		# TODO:
		# o Handle in-line comments, '... # ...'.

		$line     =~ tr/ 	/  /s;
		$line     =~ s/\\/\\\\/g;

		$self -> log(debug => "\t<$line>");

		@field    = split(/\s/, $line);
		$field[0] =~ s/^\s+//; # For /^event/ below.

		$self -> clean_up_angle_brackets(\@field);

		$g_index  = first_index{$_ =~ /^(?:~|::=|=$)/} @field;

		if ($g_index > 0)
		{
			$lhs = join(' ', @field[0 .. $g_index - 1]);

			$self -> log(info => "lhs => <$lhs>");

			if ($lhs eq ':default')
			{
				# Discard ':default' and '='.

				shift @field;
				shift @field;

				my(@indexes) = indexes{$_ =~ /^=>$/} @field;
				@field       = map{"$field[$_ - 1] = $field[$_ + 1]"} sort{$field[$a] cmp $field[$b]} @indexes;

				push @default, $lhs, @field;

				next;
			}
			elsif ($lhs eq ':discard')
			{
				# Discard ':discard' and '~'.

				push @discard, $lhs, $field[2];

				next;
			}
			elsif ($lhs eq ':lexeme')
			{
				# Discard ':lexeme' and '~'.

				$self -> process_rhs($start, \%node, \@field, $field[2]);

				next;
			}
			elsif ($lhs =~ /^event/)
			{
				push @event, join(' ', @field);

				next;
			}
			elsif ($lhs eq 'lexeme default')
			{
				# Clean up the 'lexeme default' line, which may look like one of:
				# o lexeme default = action => [start,length,value]
				# o lexeme default = action => [start,length,value] bless => ::name
				# Steps:
				# o Check for spaces in '[start, length, value]'.
				# o Combine these 2 or 3 fields into 1.

				@field       = @field[3 .. $#field];
				my(@indexes) = indexes{$_ =~ /[[\]]/} @field;

				# If the '[' and ']' are at different indexes, then spaces were found.

				if ($#indexes > 0)
				{
					splice
					(
						@field,
						$indexes[0],
						$indexes[$#indexes],
						join('', @field[$indexes[0] .. $indexes[$#indexes] ]),
						@field[$indexes[$#indexes] + 1 .. $#field]
					);
				}

				push @lexeme_default, $lhs, @field;

				next;
			}
			elsif ($lhs eq ':start')
			{
				# Discard ':start' and '::='.

				$start        = $field[2];
				$node{$start} = Tree::DAG_Node -> new
					({
						attributes => {fillcolor => 'lightgreen', label => $start, shape => 'rectangle', style => 'filled'},
						name       => $start,
					});

				next;
			}

			if ( ($#discard >= 0) && ($field[0] eq $discard[$#discard]) )
			{
				# Grab the thing previously mentioned in a ':discard'.

				push @discard, $field[2];
			}
			else
			{
				# Otherwise, it's a 'normal' line.

				$self -> process_rhs($start, \%node, \@field, $lhs);
			}
		}
		elsif ($field[1] =~ /^\|\|?$/)
		{
			$self -> process_rhs($start, \%node, \@field, $lhs);
		}
	}

	# Process the things we stockpiled, since by now $start is defined.

	$self -> add_lexeme($start, \%node, \@default)              if ($#default >= 0);
	$self -> add_lexeme($start, \%node, \@discard)              if ($#discard >= 0);
	$self -> add_adverb_record($node{$start}, \@lexeme_default) if ($#lexeme_default >= 0);
	$self -> add_event_record($node{$start}, \@event)           if ($#event >= 0);

	$self -> log(info => 'Building tree');

	my($attributes);
	my($name);

	$node{$start} -> walk_down
	({
		callback => sub
		{
			my($n, $options) = @_;

			# $n -> attributues() returns a hashref, and values are never undef:
			# o fillcolor => $fillcolor.
			# o label     => $label.
			# o shape     => $shape.
			# o style     => $style.
			#
			# Fix any '<x_y>' label issues we rigged in clean_up_angle_brackets():
			# o Replace superscript '_' with real '_'.
			# o Do not replace chevrons with '<>', because dot chokes.
			#
			# There is no need to fix these things in names, because every
			# node has a defined value for both label name name, but it's
			# some labels which dot chokes on (by hiding the text of the label).

			$attributes         = $n -> attributes;
			$$attributes{label} =~ s/\x{00AF}/ /g if ($$attributes{label});
			$name               = $n -> name;

			$self -> graph -> add_node(name => $name, %$attributes);

			if ($n -> mother)
			{
				$self -> graph -> add_edge(from => $n -> mother -> name, to => $name);
			}

			# 1 => Keep walking.

			return 1;
		},
		_depth => 0,
	});

	$self -> log(info => 'Rendering graph');

	my($output_file) = $self -> output_file;

	$self -> graph -> run(format => $self -> format, output_file => $output_file);

	my($tree_file) = $self -> tree_file;

	if ($tree_file)
	{
		$self -> log(info => 'Printing tree');

		open(OUT, '>', $tree_file) || die "Can't open(> $tree_file): $!\n";
		print OUT map{"$_\n"} @{$node{$start} -> tree2string({no_attributes => 1})};
		close OUT;
	}

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
