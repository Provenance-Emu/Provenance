#!/bin/sh

g++ -Wall -O2 -o gen-results gen-results.cpp && \
	./gen-results &&	\
	pceas -raw adc.asm &&	\
	pceas -raw sbc.asm
