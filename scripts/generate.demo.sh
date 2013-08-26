#!/bin/bash

scripts/bnf2graph.sh c.ast
scripts/bnf2graph.sh json.1
scripts/bnf2graph.sh json.2
scripts/bnf2graph.sh stringparser
scripts/bnf2graph.sh termcap.info

perl -Ilib scripts/generate.demo.pl

cp html/* $DR/Perl-modules/html/marpax.grammar.graphviz2/
