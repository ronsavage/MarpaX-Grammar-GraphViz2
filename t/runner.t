use strict;
use warnings;

use Algorithm::Diff;

use File::Temp;

use MarpaX::Grammar::GraphViz2;

use Path::Tiny;   # For path().
use Perl6::Slurp; # For slurp().

use Test::More;

# ------------------------------------------------

sub process
{
	my($file_name) = @_;

	# The EXLOCK option is for BSD-based systems.

	my($temp_dir)        = File::Temp -> newdir('temp.XXXX', CLEANUP => 1, EXLOCK => 0, TMPDIR => 1);
	my($temp_dir_name)   = $temp_dir -> dirname;
	my($test_file_name)  = path($temp_dir_name, "$file_name.test.log");
	my($log_file_name)   = path('share', "$file_name.log");
	my($marpa_file_name) = path('share', 'metag.bnf');
	my($user_file_name)  = path('share', "$file_name.bnf");

	my($parser) = MarpaX::Grammar::Parser -> new
	(
		legend         => 1,
		marpa_bnf_file => "$marpa_file_name",
		maxlevel       => 'debug',
		user_bnf_file  => "$user_file_name",
	);

	isa_ok($parser, 'MarpaX::Grammar::Parser', 'new() returned correct object type');
	is($parser -> user_bnf_file, $user_file_name, 'input_file() returns correct string');
	is($parser -> logger, '', 'logger() returns correct string');

	my(@log) = $parser -> run;

	is(slurp("$log_file_name", {utf8 => 1}), slurp("$test_file_name", {utf8 => 1}), "$file_name: Output log matches shipped log");

} # End of process.

# ------------------------------------------------

BEGIN {use_ok('MarpaX::Grammar::Parser'); }

for (qw/stringparser/)
{
	process($_);
}

done_testing;
