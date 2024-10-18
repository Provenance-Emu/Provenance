
#include <stdio.h>
#include <string.h>
#include "YaccParser.hxx"

//extern int YaccParser::yyparse();
//extern void YaccParser::set_input(const char *);
//extern int yyrestart(FILE *);

int main(int argc, char **argv) {

#ifndef BM
	YaccParser::parse(argv[1]);
	printf("\n= %d\n", YaccParser::getResult()->evaluate());
#else
	char buf[30];

	sprintf(buf, "1+2+3+4+5+6+7");
	YaccParser::parse(buf);
	Expression *e = YaccParser::getResult();

	for(int i=0; i<100000000; i++) {
		// printf("%d\n", e->evaluate());
		e->evaluate();
	}
#endif


}
