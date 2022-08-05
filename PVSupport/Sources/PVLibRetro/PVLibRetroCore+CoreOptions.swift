//
//  PVLibRetroCore+CoreOptions.swift
//  PVSupport
//
//  Created by Joseph Mattiello on 8/5/22.
//  Copyright © 2022 Provenance Emu. All rights reserved.
//

import Foundation

///* Array of retro_core_option_v2_category structs,
// * terminated by NULL
// * > If NULL, all entries in definitions array
// *   will have no category and will be shown at
// *   the top level of the frontend core option
// *   interface
// * > Will be ignored if frontend does not have
// *   core option category support */
//struct retro_core_option_v2_category *categories;
//
///* Array of retro_core_option_v2_definition structs,
// * terminated by NULL */
//struct retro_core_option_v2_definition *definitions;
//struct retro_core_option_v2_definition
//{
//   const char *key;
//   const char *desc;
//   const char *desc_categorized;
//   const char *info;
//   const char *info_categorized;
//   const char *category_key;
//   struct retro_core_option_value values[RETRO_NUM_CORE_OPTION_VALUES_MAX];
//   const char *default_value;
//};

extension PVLibRetroCore: CoreOptional {
    public static var options: [CoreOption] = {
        var options = [CoreOption]()

//        let videoGroup = CoreOption.group(.init(title: "Video",
//                                                                          description: "Change the way Gambatte renders games."),
//                                          subOptions: [paletteOption])
//
//        options.append(videoGroup)
        return options
    }()
    
    func test() {
//        guard let options: retro_core_options_v2 = core_options?.pointee else { return }
//        core_options?.pointee;
    }
}
