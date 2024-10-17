mkdir -p obj
mkdir -p obj/vu

src="." # or an absolute path, like "/home/user/rsp"
obj="$src/obj"

OBJ_LIST="\
    $obj/module.o \
    $obj/su.o \
    $obj/vu/vu.o \
    $obj/vu/multiply.o \
    $obj/vu/add.o \
    $obj/vu/select.o \
    $obj/vu/logical.o \
    $obj/vu/divide.o"

FLAGS_ANSI="-fPIC -DPLUGIN_API_VERSION=0x0101 -mstackrealign -Wall -pedantic"

if [ `uname -m` == 'x86_64' ]; then
FLAGS_x86="\
    -masm=intel \
    -fPIC \
    -DPLUGIN_API_VERSION=0x0101 \
    -DARCH_MIN_SSE2 \
    -march=native \
    -mstackrealign \
    -Wall \
    -pedantic \
    -Wall -Wshadow -Wredundant-decls -Wextra -Wcast-align -Wcast-qual \
    -Wdisabled-optimization -Wformat=2 -Winit-self -Wlogical-op
    -Wmissing-include-dirs -Wstrict-overflow=1 -Wundef -Wno-unused \
    -Wno-variadic-macros -Wno-parentheses -fdiagnostics-show-option"
else
FLAGS_x86="\
    -masm=intel \
    -DPLUGIN_API_VERSION=0x0101 \
    -DARCH_MIN_SSE2 \
    -march=native \
    -mstackrealign \
    -Wall \
    -pedantic \
    -Wall -Wshadow -Wredundant-decls -Wextra -Wcast-align -Wcast-qual \
    -Wdisabled-optimization -Wformat=2 -Winit-self -Wlogical-op
    -Wmissing-include-dirs -Wstrict-overflow=1 -Wundef -Wno-unused \
    -Wno-variadic-macros -Wno-parentheses -fdiagnostics-show-option"
fi
C_FLAGS=$FLAGS_x86 # default since Intel SIMD was the most tested

echo Compiling C source code...
cc -S -Os $C_FLAGS -o $obj/module.s  $src/module.c
cc -S -O3 $C_FLAGS -o $obj/su.s      $src/su.c
cc -S -O3 $C_FLAGS -o $obj/vu/vu.s       $src/vu/vu.c
cc -S -O3 $C_FLAGS -o $obj/vu/multiply.s $src/vu/multiply.c
cc -S -O3 $C_FLAGS -o $obj/vu/add.s      $src/vu/add.c
cc -S -O3 $C_FLAGS -o $obj/vu/select.s   $src/vu/select.c
cc -S -O3 $C_FLAGS -o $obj/vu/logical.s  $src/vu/logical.c
cc -S -O2 $C_FLAGS -o $obj/vu/divide.s   $src/vu/divide.c

echo Assembling compiled sources...
as -o $obj/module.o $obj/module.s
as -o $obj/su.o     $obj/su.s
as -o $obj/vu/vu.o  $obj/vu/vu.s
as -o $obj/vu/multiply.o $obj/vu/multiply.s
as -o $obj/vu/add.o      $obj/vu/add.s
as -o $obj/vu/select.o   $obj/vu/select.s
as -o $obj/vu/logical.o  $obj/vu/logical.s
as -o $obj/vu/divide.o   $obj/vu/divide.s

echo Linking assembled object files...
ld --shared -o $obj/rspdebug.so -lc $OBJ_LIST
strip -o $obj/rsp.so $obj/rspdebug.so --strip-all
