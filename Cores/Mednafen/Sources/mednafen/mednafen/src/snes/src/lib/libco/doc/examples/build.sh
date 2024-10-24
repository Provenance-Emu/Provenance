cc -O3 -fomit-frame-pointer -I../.. -o libco.o -c ../../libco.c
c++ -O3 -fomit-frame-pointer -I../.. -c test_timing.cpp
c++ -O3 -fomit-frame-pointer -o test_timing libco.o test_timing.o
c++ -O3 -fomit-frame-pointer -I../.. -c test_args.cpp
c++ -O3 -fomit-frame-pointer -o test_args libco.o test_args.o
c++ -O3 -fomit-frame-pointer -I../.. -c test_serialization.cpp
c++ -O3 -fomit-frame-pointer -o test_serialization libco.o test_serialization.o
rm -f *.o
