#!/bin/bash

rm -rf $DR/Perl-modules/html/marpax.grammar.graphviz2/$1.svg

scripts/bnf2graph.sh $1 $2 $3 $4 $5; cp html/$1.svg $DR/Perl-modules/html/marpax.grammar.graphviz2/
