import ProjectDescription

/// Buildbot libretro dylibs for one focused app, as two Run Scripts:
/// pre  — pick the names' URLs from the generated urls.txt / urls-tv.txt and fetch them;
/// post — wrap them as <name>.libretro.framework in the app and validate.
/// The URL comes from the generated list (cores.yml → generate_core_lists.py) because a few
/// cores ship neutral filenames (ppsspp_libretro.dylib.zip) without an _ios/_tvos suffix.
public enum LibretroCores {
    public static func scripts(slug: String, names: [String]) -> (pre: [TargetScript], post: [TargetScript]) {
        guard !names.isEmpty else { return ([], []) }
        let frameworks = names.map { $0.split(separator: "_").joined(separator: ".") }
        let pattern = names.joined(separator: "|")
        let pre: TargetScript = .pre(
            script: #"""
            set -euo pipefail
            # LIBRETRO_CORES: \#(names.joined(separator: " "))
            repo="${SRCROOT}/.."
            scripts="${repo}/CoresRetro/RetroArch/scripts"
            case "${PLATFORM_NAME}" in
              appletvos|appletvsimulator) list="${scripts}/urls-tv.txt" ;;
              *) list="${scripts}/urls.txt" ;;
            esac
            mkdir -p "${DERIVED_FILE_DIR}"
            grep -E '^https://.*/(\#(pattern))_libretro(_ios|_tvos)?\.dylib\.zip$' "${list}" > "${DERIVED_FILE_DIR}/urls.txt" || true
            got=$(grep -c . "${DERIVED_FILE_DIR}/urls.txt" || true)
            if [ "${got}" != "\#(names.count)" ]; then
              echo "error: expected \#(names.count) libretro URLs in ${list}, found ${got}:"
              cat "${DERIVED_FILE_DIR}/urls.txt"
              exit 1
            fi
            SRCROOT="${repo}" /bin/bash "${scripts}/get-modules.sh" --urls "${DERIVED_FILE_DIR}/urls.txt"
            """#,
            name: "Get libretro cores (\(slug))",
            basedOnDependencyAnalysis: false
        )
        let post: TargetScript = .post(
            script: #"""
            set -euo pipefail
            repo="${SRCROOT}/.."
            /bin/bash "${repo}/CoresRetro/RetroArch/scripts/make_frameworks_retroarch.sh" "${repo}/CoresRetro/RetroArch" "${DERIVED_FILE_DIR}/urls.txt"
            # make_frameworks_retroarch.sh always adds cores.yml "local: true" cores; keep only the
            # focused list. A framework is <name with _ as .>.framework (snes9x_libretro -> snes9x.libretro).
            fw_dir="${BUILT_PRODUCTS_DIR}/${FRAMEWORKS_FOLDER_PATH}"
            wanted=" \#(frameworks.map { "\($0).libretro.framework" }.joined(separator: " ")) "
            for name in \#(frameworks.joined(separator: " ")); do
              if [ ! -d "${fw_dir}/${name}.libretro.framework" ]; then
                echo "error: missing ${name}.libretro.framework in ${fw_dir}"
                exit 1
              fi
            done
            for fw in "${fw_dir}"/*.libretro.framework; do
              [ -d "${fw}" ] || continue
              case "${wanted}" in
                *" $(basename "${fw}") "*) ;;
                *) echo "Removing non-focused ${fw##*/}"; rm -rf "${fw}" ;;
              esac
            done
            /bin/bash "${repo}/CoresRetro/RetroArch/scripts/validate_frameworks.sh"
            """#,
            name: "Generate libretro frameworks (\(slug))",
            basedOnDependencyAnalysis: false
        )
        return ([pre], [post])
    }
}
