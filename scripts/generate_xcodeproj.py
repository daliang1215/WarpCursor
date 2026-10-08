#!/usr/bin/env python3
"""生成 WarpCursor.xcodeproj（供 Mac App Store 打包 / Xcode 本地开发）。

用法：在项目根目录执行
    python3 scripts/generate_xcodeproj.py

脚本会扫描 Sources/WarpCursor/*.swift 与 Resources/ 下的资源，
生成 WarpCursor.xcodeproj/project.pbxproj。之后用 Xcode 打开即可
Archive 并上传 App Store Connect（需自行在 Signing 中选择 Team）。
"""
import os
import uuid

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC_DIR = os.path.join(ROOT, "Sources", "WarpCursor")
RES_DIR = os.path.join(ROOT, "Resources")
OUT = os.path.join(ROOT, "WarpCursor.xcodeproj", "project.pbxproj")

BUNDLE_ID = "com.warpcursor.app"   # 上架前可在 Xcode 里改成自己的反向域名
DEPLOYMENT_TARGET = "14.0"
MARKETING_VERSION = "1.0"


def uid():
    return uuid.uuid4().hex[:24].upper()


def q(s):
    """OpenStep plist 字符串转义。"""
    if any(c in s for c in ' \t"\\/(){}<>'):
        return '"%s"' % s.replace("\\", "\\\\").replace('"', '\\"')
    return s


def main():
    swift_files = sorted(f for f in os.listdir(SRC_DIR) if f.endswith(".swift"))
    assert swift_files, "no swift sources found"

    # 资源：进 Resources phase 的只有运行时要读的文件
    res_phase_files = ["AppIcon.icns", "MenuBarIcon.png"]
    res_group_files = sorted(f for f in os.listdir(RES_DIR)
                             if os.path.isfile(os.path.join(RES_DIR, f)))
    for f in res_phase_files:
        assert f in res_group_files, f"missing resource {f}"

    ids = {}
    def newid(name):
        i = uid()
        ids[name] = i
        return i

    # ---- 顶层对象 ----
    proj = newid("PBXProject")
    target = newid("PBXNativeTarget")
    prod_ref = newid("productRef")
    cfglist_proj = newid("cfglist_proj")
    cfglist_target = newid("cfglist_target")
    cfg_proj_dbg = newid("cfg_proj_dbg")
    cfg_proj_rel = newid("cfg_proj_rel")
    cfg_tgt_dbg = newid("cfg_tgt_dbg")
    cfg_tgt_rel = newid("cfg_tgt_rel")
    phase_sources = newid("PBXSourcesBuildPhase")
    phase_resources = newid("PBXResourcesBuildPhase")
    grp_main = newid("grp_main")
    grp_sources = newid("grp_sources")
    grp_resources = newid("grp_resources")
    grp_products = newid("grp_products")

    buildfiles = []      # (id, fileRefId)
    filerefs = []        # (id, kind, name)
    for f in swift_files:
        fr = newid("fr_" + f)
        bf = newid("bf_" + f)
        filerefs.append((fr, "swift", f))
        buildfiles.append((bf, fr, "sources"))
    for f in res_phase_files:
        fr = newid("fr_" + f)
        bf = newid("bf_" + f)
        filerefs.append((fr, "res", f))
        buildfiles.append((bf, fr, "resources"))
    for f in res_group_files:
        if f not in res_phase_files and not any(x[2] == f for x in filerefs):
            fr = newid("fr_" + f)
            filerefs.append((fr, "res", f))   # 只进 group，不进 build phase（如 Info.plist）

    L = []
    A = L.append
    A("// !$*UTF8*$!")
    A("{")
    A("\tarchiveVersion = 1;")
    A("\tclasses = {")
    A("\t};")
    A("\tobjectVersion = 56;")
    A("\tobjects = {")
    A("")

    # PBXBuildFile
    A("/* Begin PBXBuildFile section */")
    for bf, fr, _ in buildfiles:
        A(f"\t\t{bf} = {{isa = PBXBuildFile; fileRef = {fr}; }};")
    A("/* End PBXBuildFile section */")
    A("")

    # PBXFileReference
    A("/* Begin PBXFileReference section */")
    for fr, kind, name in filerefs:
        if kind == "swift":
            A(f"\t\t{fr} = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {q(name)}; sourceTree = \"<group>\"; }};")
        else:
            ftype = {"icns": "image.icns", "png": "image.png"}.get(name.rsplit(".", 1)[-1], "text")
            A(f"\t\t{fr} = {{isa = PBXFileReference; lastKnownFileType = {ftype}; path = {q(name)}; sourceTree = \"<group>\"; }};")
    A(f"\t\t{prod_ref} = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = WarpCursor.app; sourceTree = BUILT_PRODUCTS_DIR; }};")
    A("/* End PBXFileReference section */")
    A("")

    # PBXGroup
    A("/* Begin PBXGroup section */")
    src_kids = ", ".join(fr for fr, k, _ in filerefs if k == "swift")
    res_kids = ", ".join(fr for fr, k, _ in filerefs if k == "res")
    A(f"\t\t{grp_main} = {{isa = PBXGroup; children = ({grp_sources}, {grp_resources}, {grp_products}); sourceTree = \"<group>\"; }};")
    A(f"\t\t{grp_products} = {{isa = PBXGroup; children = ({prod_ref}); name = Products; sourceTree = \"<group>\"; }};")
    A(f"\t\t{grp_resources} = {{isa = PBXGroup; children = ({res_kids}); path = Resources; sourceTree = \"<group>\"; }};")
    A(f"\t\t{grp_sources} = {{isa = PBXGroup; children = ({src_kids}); path = Sources/WarpCursor; sourceTree = \"<group>\"; }};")
    A("/* End PBXGroup section */")
    A("")

    # PBXNativeTarget
    A("/* Begin PBXNativeTarget section */")
    A(f"\t\t{target} = {{")
    A("\t\t\tisa = PBXNativeTarget;")
    A(f"\t\t\tbuildConfigurationList = {cfglist_target};")
    A("\t\t\tbuildPhases = (")
    A(f"\t\t\t\t{phase_sources},")
    A(f"\t\t\t\t{phase_resources},")
    A("\t\t\t);")
    A("\t\t\tbuildRules = (")
    A("\t\t\t);")
    A("\t\t\tdependencies = (")
    A("\t\t\t);")
    A('\t\t\tname = WarpCursor;')
    A(f"\t\t\tproductName = WarpCursor;")
    A(f"\t\t\tproductReference = {prod_ref};")
    A('\t\t\tproductType = "com.apple.product-type.application";')
    A("\t\t};")
    A("/* End PBXNativeTarget section */")
    A("")

    # PBXProject
    A("/* Begin PBXProject section */")
    A(f"\t\t{proj} = {{")
    A("\t\t\tisa = PBXProject;")
    A("\t\t\tattributes = {")
    A("\t\t\t\tBuildIndependentTargetsInParallel = 1;")
    A("\t\t\t\tLastUpgradeCheck = 1600;")
    A("\t\t\t\tTargetAttributes = {")
    A(f"\t\t\t\t\t{target} = {{")
    A("\t\t\t\t\t\tCreatedOnToolsVersion = 16.0;")
    A("\t\t\t\t\t};")
    A("\t\t\t\t};")
    A("\t\t\t};")
    A(f"\t\t\tbuildConfigurationList = {cfglist_proj};")
    A('\t\t\tcompatibilityVersion = "Xcode 14.0";')
    A('\t\t\tdevelopmentRegion = en;')
    A("\t\t\thasScannedForEncodings = 0;")
    A("\t\t\tknownRegions = (en);")
    A(f"\t\t\tmainGroup = {grp_main};")
    A(f"\t\t\tproductRefGroup = {grp_products};")
    A("\t\t\tprojectDirPath = \"\";")
    A("\t\t\tprojectRoot = \"\";")
    A("\t\t\ttargets = (")
    A(f"\t\t\t\t{target},")
    A("\t\t\t);")
    A("\t\t};")
    A("/* End PBXProject section */")
    A("")

    # Build phases
    A("/* Begin PBXResourcesBuildPhase section */")
    res_bfs = ", ".join(f"\n\t\t\t\t{bf}" for bf, _, kind in buildfiles if kind == "resources")
    A(f"\t\t{phase_resources} = {{")
    A("\t\t\tisa = PBXResourcesBuildPhase;")
    A("\t\t\tbuildActionMask = 2147483647;")
    A("\t\t\tfiles = (" + res_bfs + ",")
    A("\t\t\t);")
    A("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
    A("\t\t};")
    A("/* End PBXResourcesBuildPhase section */")
    A("")
    A("/* Begin PBXSourcesBuildPhase section */")
    src_bfs = ", ".join(f"\n\t\t\t\t{bf}" for bf, _, kind in buildfiles if kind == "sources")
    A(f"\t\t{phase_sources} = {{")
    A("\t\t\tisa = PBXSourcesBuildPhase;")
    A("\t\t\tbuildActionMask = 2147483647;")
    A("\t\t\tfiles = (" + src_bfs + ",")
    A("\t\t\t);")
    A("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
    A("\t\t};")
    A("/* End PBXSourcesBuildPhase section */")
    A("")

    # XCBuildConfiguration
    def cfg(cid, name, settings):
        A(f"\t\t{cid} = {{")
        A("\t\t\tisa = XCBuildConfiguration;")
        A("\t\t\tbuildSettings = {")
        for k, v in settings.items():
            A(f"\t\t\t\t{k} = {v};")
        A("\t\t\t};")
        A(f"\t\t\tname = {name};")
        A("\t\t};")

    A("/* Begin XCBuildConfiguration section */")
    proj_common = {
        "ALWAYS_SEARCH_USER_PATHS": "NO",
        "CLANG_ANALYZER_NONNULL": "YES",
        "CLANG_CXX_LANGUAGE_STANDARD": '"gnu++20"',
        "DEBUG_INFORMATION_FORMAT": "dwarf-with-dsym",
        "ENABLE_STRICT_OBJC_MSGSEND": "YES",
        "GCC_C_LANGUAGE_STANDARD": "gnu17",
        "MARKETING_VERSION": MARKETING_VERSION,
        "MTL_FAST_MATH": "YES",
        "SWIFT_VERSION": "5.0",
    }
    cfg(cfg_proj_dbg, "Debug", {**proj_common,
        "CURRENT_PROJECT_VERSION": "1",
        "MTL_ENABLE_DEBUG_INFO": "INCLUDE_SOURCE",
        "ONLY_ACTIVE_ARCH": "YES",
    })
    cfg(cfg_proj_rel, "Release", {**proj_common,
        "CURRENT_PROJECT_VERSION": "1",
        "MTL_ENABLE_DEBUG_INFO": "NO",
    })
    tgt_common = {
        "CODE_SIGN_ENTITLEMENTS": "Resources/WarpCursor.entitlements",
        "CODE_SIGN_STYLE": "Automatic",
        "DEVELOPMENT_TEAM": '""',
        "ENABLE_HARDENED_RUNTIME": "YES",
        "GENERATE_INFOPLIST_FILE": "NO",
        "INFOPLIST_FILE": "Resources/Info.plist",
        "LD_RUNPATH_SEARCH_PATHS": '"$(inherited) @executable_path/../Frameworks"',
        "MACOSX_DEPLOYMENT_TARGET": DEPLOYMENT_TARGET,
        "PRODUCT_BUNDLE_IDENTIFIER": BUNDLE_ID,
        "PRODUCT_NAME": '"$(TARGET_NAME)"',
        "SWIFT_EMIT_LOC_STRINGS": "YES",
    }
    cfg(cfg_tgt_dbg, "Debug", {**tgt_common,
        "DEBUG_INFORMATION_FORMAT": "dwarf",
        "MTL_ENABLE_DEBUG_INFO": "INCLUDE_SOURCE",
        "ONLY_ACTIVE_ARCH": "YES",
        "SWIFT_ACTIVE_COMPILATION_CONDITIONS": "DEBUG",
        "SWIFT_OPTIMIZATION_LEVEL": '"-Onone"',
    })
    cfg(cfg_tgt_rel, "Release", {**tgt_common,
        "COPY_PHASE_STRIP": "NO",
        "DEBUG_INFORMATION_FORMAT": '"dwarf-with-dsym"',
    })
    A("/* End XCBuildConfiguration section */")
    A("")

    # XCConfigurationList
    A("/* Begin XCConfigurationList section */")
    for lid, cfgs in ((cfglist_proj, (cfg_proj_dbg, cfg_proj_rel)),
                      (cfglist_target, (cfg_tgt_dbg, cfg_tgt_rel))):
        A(f"\t\t{lid} = {{")
        A("\t\t\tisa = XCConfigurationList;")
        A("\t\t\tbuildConfigurations = (")
        A(f"\t\t\t\t{cfgs[0]},")
        A(f"\t\t\t\t{cfgs[1]},")
        A("\t\t\t);")
        A("\t\t\tdefaultConfigurationIsVisible = 0;")
        A("\t\t\tdefaultConfigurationName = Release;")
        A("\t\t};")
    A("/* End XCConfigurationList section */")
    A("")
    A("\t};")
    A(f"\trootObject = {proj};")
    A("}")

    os.makedirs(os.path.join(ROOT, "WarpCursor.xcodeproj"), exist_ok=True)
    with open(OUT, "w", encoding="utf-8") as f:
        f.write("\n".join(L) + "\n")
    print("wrote", OUT, f"({len(swift_files)} swift files)")


if __name__ == "__main__":
    main()
