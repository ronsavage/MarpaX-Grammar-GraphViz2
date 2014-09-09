#!/bin/bash

if [ -n "$1" ]; then
	echo Processing c.ast. Wait 6 m 47 secs
	scripts/bnf2graph.sh c.ast -legend 1
fi

scripts/bnf2graph.sh json.1 -legend 1
scripts/bnf2graph.sh json.2 -legend 1
scripts/bnf2graph.sh json.3 -legend 1
scripts/bnf2graph.sh stringparser -legend 1
scripts/bnf2graph.sh termcap.info -legend 1

perl -Ilib scripts/generate.demo.pl

cp html/* $DR/Perl-modules/html/marpax.grammar.graphviz2/

echo Also, copy demo files to the real web site...
