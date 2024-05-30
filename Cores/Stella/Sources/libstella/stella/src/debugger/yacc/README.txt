Makefile.yacc    - Not part of the regular stella build!
YaccParser.cxx   - C++ wrapper for generated parser, includes hand-coded lexer
YaccParser.hxx   - Include in user code, declares public "methods" (actually functions)
calctest.c       - Not part of stella! Used for testing the lexel/parser.
module.mk        - Used for regular Stella build
stella.y         - Yacc/Bison source for parser
y.tab.c, y.tab.h - Generated parser. NOT BUILT AUTOMATICALLY!

I've only tested stella.y with GNU bison 1.35 and (once) with Berkeley
Yacc 1.9. Hopefully your favorite version will work, too :)

Even though they're generated, y.tab.c and .h are in SVN. This is so that
people who don't have a local copy of bison or yacc can still compile
Stella.

If you modify stella.y, you MUST run "make -f Makefile.yacc" in this directory.
This will regenerate y.tab.c and y.tab.h. Do this before "svn commit".

If you're hacking the parser, you can test it without the rest of Stella
by running "make -f Makefile.yacc calctest" in this directory, then running
calctest with an expression as its argument:

./calctest '2+2'
= 4

If you're trying to benchmark the lexer/parser, try adding -DBM to the
g++ command that builds calctest.
