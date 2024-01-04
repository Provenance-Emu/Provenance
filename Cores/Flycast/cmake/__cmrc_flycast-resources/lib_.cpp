        #include <cmrc/cmrc.hpp>
#include <map>
#include <utility>

namespace cmrc {
namespace flycast {

namespace res_chars {
// These are the files which are available in this resource library
// Pointers to resources/flash/alienfnt.nvmem.zip
extern const char* const f_64a9_flash_alienfnt_nvmem_zip_begin;
extern const char* const f_64a9_flash_alienfnt_nvmem_zip_end;
// Pointers to resources/flash/gunsur2.nvmem.zip
extern const char* const f_7a82_flash_gunsur2_nvmem_zip_begin;
extern const char* const f_7a82_flash_gunsur2_nvmem_zip_end;
// Pointers to resources/flash/mazan.nvmem.zip
extern const char* const f_065f_flash_mazan_nvmem_zip_begin;
extern const char* const f_065f_flash_mazan_nvmem_zip_end;
// Pointers to resources/flash/otrigger.nvmem.zip
extern const char* const f_3470_flash_otrigger_nvmem_zip_begin;
extern const char* const f_3470_flash_otrigger_nvmem_zip_end;
// Pointers to resources/flash/wldkicks.nvmem.zip
extern const char* const f_39e4_flash_wldkicks_nvmem_zip_begin;
extern const char* const f_39e4_flash_wldkicks_nvmem_zip_end;
// Pointers to resources/flash/wldkicksj.nvmem.zip
extern const char* const f_a91f_flash_wldkicksj_nvmem_zip_begin;
extern const char* const f_a91f_flash_wldkicksj_nvmem_zip_end;
// Pointers to resources/flash/wldkicksu.nvmem.zip
extern const char* const f_ab52_flash_wldkicksu_nvmem_zip_begin;
extern const char* const f_ab52_flash_wldkicksu_nvmem_zip_end;
// Pointers to resources/flash/f355.nvmem.zip
extern const char* const f_cf18_flash_f355_nvmem_zip_begin;
extern const char* const f_cf18_flash_f355_nvmem_zip_end;
// Pointers to resources/flash/f355twin.nvmem.zip
extern const char* const f_2585_flash_f355twin_nvmem_zip_begin;
extern const char* const f_2585_flash_f355twin_nvmem_zip_end;
// Pointers to resources/flash/f355twn2.nvmem.zip
extern const char* const f_e20f_flash_f355twn2_nvmem_zip_begin;
extern const char* const f_e20f_flash_f355twn2_nvmem_zip_end;
// Pointers to resources/flash/dirtypig.nvmem.zip
extern const char* const f_3451_flash_dirtypig_nvmem_zip_begin;
extern const char* const f_3451_flash_dirtypig_nvmem_zip_end;
// Pointers to resources/flash/dirtypig.nvmem2.zip
extern const char* const f_c994_flash_dirtypig_nvmem2_zip_begin;
extern const char* const f_c994_flash_dirtypig_nvmem2_zip_end;
// Pointers to resources/flash/vf4.nvmem.zip
extern const char* const f_aa77_flash_vf4_nvmem_zip_begin;
extern const char* const f_aa77_flash_vf4_nvmem_zip_end;
// Pointers to resources/flash/vf4evob.nvmem.zip
extern const char* const f_fa91_flash_vf4evob_nvmem_zip_begin;
extern const char* const f_fa91_flash_vf4evob_nvmem_zip_end;
// Pointers to resources/flash/vf4tuned.nvmem.zip
extern const char* const f_bbdd_flash_vf4tuned_nvmem_zip_begin;
extern const char* const f_bbdd_flash_vf4tuned_nvmem_zip_end;
// Pointers to fonts/printer_ascii8x16.bin
extern const char* const f_86fc_fonts_printer_ascii8x16_bin_begin;
extern const char* const f_86fc_fonts_printer_ascii8x16_bin_end;
// Pointers to fonts/printer_ascii12x24.bin
extern const char* const f_9a8f_fonts_printer_ascii12x24_bin_begin;
extern const char* const f_9a8f_fonts_printer_ascii12x24_bin_end;
// Pointers to fonts/printer_kanji16x16.bin
extern const char* const f_cbc3_fonts_printer_kanji16x16_bin_begin;
extern const char* const f_cbc3_fonts_printer_kanji16x16_bin_end;
// Pointers to fonts/printer_kanji24x24.bin
extern const char* const f_2e10_fonts_printer_kanji24x24_bin_begin;
extern const char* const f_2e10_fonts_printer_kanji24x24_bin_end;
// Pointers to fonts/biosfont.bin
extern const char* const f_df08_fonts_biosfont_bin_begin;
extern const char* const f_df08_fonts_biosfont_bin_end;
}

namespace {

const cmrc::detail::index_type&
get_root_index() {
    static cmrc::detail::directory root_directory_;
    static cmrc::detail::file_or_directory root_directory_fod{root_directory_};
    static cmrc::detail::index_type root_index;
    root_index.emplace("", &root_directory_fod);
    struct dir_inl {
        class cmrc::detail::directory& directory;
    };
    dir_inl root_directory_dir{root_directory_};
    (void)root_directory_dir;
    static auto f_a394_flash_dir = root_directory_dir.directory.add_subdir("flash");
    root_index.emplace("flash", &f_a394_flash_dir.index_entry);
    static auto f_980d_fonts_dir = root_directory_dir.directory.add_subdir("fonts");
    root_index.emplace("fonts", &f_980d_fonts_dir.index_entry);
    root_index.emplace(
        "flash/alienfnt.nvmem.zip",
        f_a394_flash_dir.directory.add_file(
            "alienfnt.nvmem.zip",
            res_chars::f_64a9_flash_alienfnt_nvmem_zip_begin,
            res_chars::f_64a9_flash_alienfnt_nvmem_zip_end
        )
    );
    root_index.emplace(
        "flash/gunsur2.nvmem.zip",
        f_a394_flash_dir.directory.add_file(
            "gunsur2.nvmem.zip",
            res_chars::f_7a82_flash_gunsur2_nvmem_zip_begin,
            res_chars::f_7a82_flash_gunsur2_nvmem_zip_end
        )
    );
    root_index.emplace(
        "flash/mazan.nvmem.zip",
        f_a394_flash_dir.directory.add_file(
            "mazan.nvmem.zip",
            res_chars::f_065f_flash_mazan_nvmem_zip_begin,
            res_chars::f_065f_flash_mazan_nvmem_zip_end
        )
    );
    root_index.emplace(
        "flash/otrigger.nvmem.zip",
        f_a394_flash_dir.directory.add_file(
            "otrigger.nvmem.zip",
            res_chars::f_3470_flash_otrigger_nvmem_zip_begin,
            res_chars::f_3470_flash_otrigger_nvmem_zip_end
        )
    );
    root_index.emplace(
        "flash/wldkicks.nvmem.zip",
        f_a394_flash_dir.directory.add_file(
            "wldkicks.nvmem.zip",
            res_chars::f_39e4_flash_wldkicks_nvmem_zip_begin,
            res_chars::f_39e4_flash_wldkicks_nvmem_zip_end
        )
    );
    root_index.emplace(
        "flash/wldkicksj.nvmem.zip",
        f_a394_flash_dir.directory.add_file(
            "wldkicksj.nvmem.zip",
            res_chars::f_a91f_flash_wldkicksj_nvmem_zip_begin,
            res_chars::f_a91f_flash_wldkicksj_nvmem_zip_end
        )
    );
    root_index.emplace(
        "flash/wldkicksu.nvmem.zip",
        f_a394_flash_dir.directory.add_file(
            "wldkicksu.nvmem.zip",
            res_chars::f_ab52_flash_wldkicksu_nvmem_zip_begin,
            res_chars::f_ab52_flash_wldkicksu_nvmem_zip_end
        )
    );
    root_index.emplace(
        "flash/f355.nvmem.zip",
        f_a394_flash_dir.directory.add_file(
            "f355.nvmem.zip",
            res_chars::f_cf18_flash_f355_nvmem_zip_begin,
            res_chars::f_cf18_flash_f355_nvmem_zip_end
        )
    );
    root_index.emplace(
        "flash/f355twin.nvmem.zip",
        f_a394_flash_dir.directory.add_file(
            "f355twin.nvmem.zip",
            res_chars::f_2585_flash_f355twin_nvmem_zip_begin,
            res_chars::f_2585_flash_f355twin_nvmem_zip_end
        )
    );
    root_index.emplace(
        "flash/f355twn2.nvmem.zip",
        f_a394_flash_dir.directory.add_file(
            "f355twn2.nvmem.zip",
            res_chars::f_e20f_flash_f355twn2_nvmem_zip_begin,
            res_chars::f_e20f_flash_f355twn2_nvmem_zip_end
        )
    );
    root_index.emplace(
        "flash/dirtypig.nvmem.zip",
        f_a394_flash_dir.directory.add_file(
            "dirtypig.nvmem.zip",
            res_chars::f_3451_flash_dirtypig_nvmem_zip_begin,
            res_chars::f_3451_flash_dirtypig_nvmem_zip_end
        )
    );
    root_index.emplace(
        "flash/dirtypig.nvmem2.zip",
        f_a394_flash_dir.directory.add_file(
            "dirtypig.nvmem2.zip",
            res_chars::f_c994_flash_dirtypig_nvmem2_zip_begin,
            res_chars::f_c994_flash_dirtypig_nvmem2_zip_end
        )
    );
    root_index.emplace(
        "flash/vf4.nvmem.zip",
        f_a394_flash_dir.directory.add_file(
            "vf4.nvmem.zip",
            res_chars::f_aa77_flash_vf4_nvmem_zip_begin,
            res_chars::f_aa77_flash_vf4_nvmem_zip_end
        )
    );
    root_index.emplace(
        "flash/vf4evob.nvmem.zip",
        f_a394_flash_dir.directory.add_file(
            "vf4evob.nvmem.zip",
            res_chars::f_fa91_flash_vf4evob_nvmem_zip_begin,
            res_chars::f_fa91_flash_vf4evob_nvmem_zip_end
        )
    );
    root_index.emplace(
        "flash/vf4tuned.nvmem.zip",
        f_a394_flash_dir.directory.add_file(
            "vf4tuned.nvmem.zip",
            res_chars::f_bbdd_flash_vf4tuned_nvmem_zip_begin,
            res_chars::f_bbdd_flash_vf4tuned_nvmem_zip_end
        )
    );
    root_index.emplace(
        "fonts/printer_ascii8x16.bin",
        f_980d_fonts_dir.directory.add_file(
            "printer_ascii8x16.bin",
            res_chars::f_86fc_fonts_printer_ascii8x16_bin_begin,
            res_chars::f_86fc_fonts_printer_ascii8x16_bin_end
        )
    );
    root_index.emplace(
        "fonts/printer_ascii12x24.bin",
        f_980d_fonts_dir.directory.add_file(
            "printer_ascii12x24.bin",
            res_chars::f_9a8f_fonts_printer_ascii12x24_bin_begin,
            res_chars::f_9a8f_fonts_printer_ascii12x24_bin_end
        )
    );
    root_index.emplace(
        "fonts/printer_kanji16x16.bin",
        f_980d_fonts_dir.directory.add_file(
            "printer_kanji16x16.bin",
            res_chars::f_cbc3_fonts_printer_kanji16x16_bin_begin,
            res_chars::f_cbc3_fonts_printer_kanji16x16_bin_end
        )
    );
    root_index.emplace(
        "fonts/printer_kanji24x24.bin",
        f_980d_fonts_dir.directory.add_file(
            "printer_kanji24x24.bin",
            res_chars::f_2e10_fonts_printer_kanji24x24_bin_begin,
            res_chars::f_2e10_fonts_printer_kanji24x24_bin_end
        )
    );
    root_index.emplace(
        "fonts/biosfont.bin",
        f_980d_fonts_dir.directory.add_file(
            "biosfont.bin",
            res_chars::f_df08_fonts_biosfont_bin_begin,
            res_chars::f_df08_fonts_biosfont_bin_end
        )
    );
    return root_index;
}

}

cmrc::embedded_filesystem get_filesystem() {
    static auto& index = get_root_index();
    return cmrc::embedded_filesystem{index};
}

} // flycast
} // cmrc
    