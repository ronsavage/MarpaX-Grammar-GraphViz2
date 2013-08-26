#!/bin/bash

scripts/bnf2graph.sh c.ast.bnf
scripts/bnf2graph.sh json.1.bnf
scripts/bnf2graph.sh json.2.bnf
scripts/bnf2graph.sh stringparser.bnf
scripts/bnf2graph.sh termcap.info.bnf

perl -Ilib scripts/generate.demo.pl

cp html/* $DR/Perl-modules/html/marpax.grammar.graphviz2/
