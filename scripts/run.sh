#!/bin/bash

rm $DR/Perl-modules/html/marpax.grammar.graphviz2/*.svg

scripts/bnf2graph.sh stringparser -max debug; cp html/*.svg $DR/Perl-modules/html/marpax.grammar.graphviz2/
