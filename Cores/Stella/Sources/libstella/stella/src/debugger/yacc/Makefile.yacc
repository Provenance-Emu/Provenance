
### Note: this Makefile not used in building the main Stella binary!

# can use "yacc" instead of "bison -y"

all: stella.y
	bison -y -d stella.y


calctest: stella.y calctest.c YaccParser.cxx YaccParser.hxx
	bison -y -d stella.y
	g++ -DPRINT -I../debugger -O2 -c YaccParser.cxx
	g++ -DBM -I../debugger -O2 -c calctest.c
	g++ -I../debugger -O2 -Wall -o calctest calctest.o YaccParser.o ../debugger/*Expression.o
	strip calctest

#clean:
#	rm -f y.tab.* lex.yy.* *.o calctest
