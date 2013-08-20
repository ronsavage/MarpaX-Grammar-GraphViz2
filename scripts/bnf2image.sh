#!/bin/bash
#
# Name: g2g.sh.
#
# Parameters:
# 1: The abbreviated name of sample input and output data files.
#	E.g. xyz simultaneously means data/xyz.bnf, data/xyz.log and html/xyz.svg.
# 2 & 3: Use for debugging. E.g.: -maxlevel debug.

perl -Ilib scripts/g2g.pl -i data/$1.bnf -o html/$1.svg -t data/$1.log $2 $3
