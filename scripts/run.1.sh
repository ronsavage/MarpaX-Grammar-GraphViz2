#!/bin/bash

rm -rf $DR/Perl-modules/html/marpax.grammar.graphviz2/$1.svg

scripts/bnf2graph.sh $1 -max debug; cp html/$1.svg $DR/Perl-modules/html/marpax.grammar.graphviz2/
