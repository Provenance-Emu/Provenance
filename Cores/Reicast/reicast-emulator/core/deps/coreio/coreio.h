#pragma once
#include "types.h"

//#define core_file FILE
typedef void* core_file;


core_file* core_fopen(const char* filename);
size_t core_fseek(core_file* fc, size_t offs, size_t origin);
int core_fread(core_file* fc, void* buff, size_t len);
int core_fclose(core_file* fc);
size_t core_fsize(core_file* fc);
size_t core_ftell(core_file* fc);