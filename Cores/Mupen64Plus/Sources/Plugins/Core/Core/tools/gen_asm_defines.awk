BEGIN {
  nasm_file = dest_dir"/asm_defines_nasm.h";
  gas_file =  dest_dir"/asm_defines_gas.h";
}

/@ASM_DEFINE offsetof_struct_[a-zA-Z_0-9]+ 0x[0-9a-fA-F]+/ {
    print "%define "$2" ("$3")" > nasm_file;
    print "#define "$2" ("$3")" > gas_file;
}

END {}
