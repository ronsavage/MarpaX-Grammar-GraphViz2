use ExtUtils::MakeMaker;

use inc::Module::Install;

# -----------------------------------------------

name 'MarpaX-Grammar-GraphViz2';

license 'artistic_2';

perl_version '5.014000';

all_from 'lib/MarpaX/Grammar/GraphViz2.pm';

install_share;

requires 'Getopt::Long'            => 2.41;
requires 'File::Basename'          => 2.82;
requires 'File::ShareDir'          => 1.03;
requires 'File::Temp'              => 0.2301;
requires 'File::Which'             => 1.09;
requires 'GraphViz2'               => 2.19;
requires 'Log::Handler'            => 0.78;
requires 'MarpaX::Grammar::Parser' => 1.02;
requires 'Moo'                     => 1.002000;
requires 'open'                    => 0;
requires 'Path::Tiny'              => 0.025;
requires 'perl'                    => '5.14.2'; # For the utf8 stuff.
requires 'Perl6::Slurp'            => 0.03;
requires 'Pod::Usage'              => 1.36;
requires 'strict'                  => 0;
requires 'utf8'                    => 0;
requires 'warnings'                => 0;

test_requires 'Test::More' => 0.98;
#test_requires 'Test::Pod'  => 1.45; # Make it optional. See t/pod.t

recursive_author_tests('xt');

WriteAll;
