#include <cstdint>

#include "oaknut/feature_detection/id_registers.hpp"

namespace oaknut::id {

inline IdRegisters read_id_registers_directly()
{
    std::uint64_t midr, pfr0, pfr1, pfr2, isar0, isar1, isar2, isar3, mmfr0, mmfr1, mmfr2, mmfr3, mmfr4, zfr0, smfr0;

#define OAKNUT_READ_REGISTER(reg, var) \
    __asm__("mrs %0, " #reg            \
            : "=r"(var))

    OAKNUT_READ_REGISTER(s3_0_c0_c0_0, midr);
    OAKNUT_READ_REGISTER(s3_0_c0_c4_0, pfr0);
    OAKNUT_READ_REGISTER(s3_0_c0_c4_1, pfr1);
    OAKNUT_READ_REGISTER(s3_0_c0_c4_2, pfr2);
    OAKNUT_READ_REGISTER(s3_0_c0_c4_4, zfr0);
    OAKNUT_READ_REGISTER(s3_0_c0_c4_5, smfr0);
    OAKNUT_READ_REGISTER(s3_0_c0_c6_0, isar0);
    OAKNUT_READ_REGISTER(s3_0_c0_c6_1, isar1);
    OAKNUT_READ_REGISTER(s3_0_c0_c6_2, isar2);
    OAKNUT_READ_REGISTER(s3_0_c0_c6_3, isar3);
    OAKNUT_READ_REGISTER(s3_0_c0_c7_0, mmfr0);
    OAKNUT_READ_REGISTER(s3_0_c0_c7_1, mmfr1);
    OAKNUT_READ_REGISTER(s3_0_c0_c7_2, mmfr2);
    OAKNUT_READ_REGISTER(s3_0_c0_c7_3, mmfr3);
    OAKNUT_READ_REGISTER(s3_0_c0_c7_4, mmfr4);

#undef OAKNUT_READ_ID_REGISTER

    return IdRegisters{
        midr,
        Pfr0Register{pfr0},
        Pfr1Register{pfr1},
        Pfr2Register{pfr2},
        Zfr0Register{zfr0},
        Smfr0Register{smfr0},
        Isar0Register{isar0},
        Isar1Register{isar1},
        Isar2Register{isar2},
        Isar3Register{isar3},
        Mmfr0Register{mmfr0},
        Mmfr1Register{mmfr1},
        Mmfr2Register{mmfr2},
        Mmfr3Register{mmfr3},
        Mmfr4Register{mmfr4},
    };
}

}  // namespace oaknut::id
