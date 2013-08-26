#!/bin/bash

perl -Ilib scripts/bnf2graph.pl -legend 1 -marpa share/metag.bnf -o html/c.ast.svg        -user share/c.ast.bnf
perl -Ilib scripts/bnf2graph.pl -legend 1 -marpa share/metag.bnf -o html/json.1.svg       -user share/json.1.bnf
perl -Ilib scripts/bnf2graph.pl -legend 1 -marpa share/metag.bnf -o html/json.2.svg       -user share/json.2.bnf
perl -Ilib scripts/bnf2graph.pl -legend 1 -marpa share/metag.bnf -o html/stringparser.svg -user share/stringparser.bnf
perl -Ilib scripts/bnf2graph.pl -legend 1 -marpa share/metag.bnf -o html/termcap.info.svg -user share/termcap.info.bnf

perl -Ilib scripts/generate.demo.pl
