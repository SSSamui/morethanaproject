#!/usr/bin/env python3
"""Writes PuppyPomodoro.xcodeproj and PuppyPomodoroLite.xcodeproj.

The projects use folder references that stay in sync with the disk (Xcode 16+),
so new .swift files in App/, Shared/, ... are picked up without editing the
project. Run this again only when targets or build settings change.
"""
import hashlib
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ID_PREFIX = "com.sssamui.puppypomodoro"
VERSION = "1.1.1"


def oid(*parts):
    return hashlib.md5("/".join(parts).encode()).hexdigest()[:24].upper()


def q(v):
    if isinstance(v, str):
        if v and re.fullmatch(r"[A-Za-z0-9_./]+", v):
            return v
        return '"' + v.replace("\\", "\\\\").replace('"', '\\"') + '"'
    if isinstance(v, list):
        return "(" + "".join(q(x) + ", " for x in v) + ")"
    if isinstance(v, dict):
        return "{" + "".join(f"{q(k)} = {q(x)}; " for k, x in v.items()) + "}"
    return str(v)


def dump(v, ind=1):
    t = "\t" * ind
    if isinstance(v, dict):
        out = "{\n"
        for k, x in v.items():
            out += f"{t}\t{q(k)} = {dump(x, ind + 1)};\n"
        return out + t + "}"
    if isinstance(v, list):
        if not v:
            return "(\n" + t + ")"
        return "(\n" + "".join(f"{t}\t{dump(x, ind + 1)},\n" for x in v) + t + ")"
    return q(v)


# name, folders, Info.plist, entitlements (full / lite), bundle suffix, screen time only
APP = ("PuppyPomodoro", ["App", "Shared", "LiveShared"], "App-Info.plist",
       ("App.entitlements", "GroupOnly.entitlements"), "", False)
EXTENSIONS = [
    ("PorkWidget", ["Widget", "Shared", "LiveShared"], "Widget-Info.plist",
     ("GroupOnly.entitlements", "GroupOnly.entitlements"), ".widget", False),
    ("PorkShieldConfig", ["ShieldConfig", "Shared"], "ShieldConfig-Info.plist",
     ("ScreenTimeExtension.entitlements", None), ".shieldconfig", True),
    ("PorkShieldAction", ["ShieldAction", "Shared"], "ShieldAction-Info.plist",
     ("ScreenTimeExtension.entitlements", None), ".shieldaction", True),
    ("PorkMonitor", ["Monitor", "Shared"], "Monitor-Info.plist",
     ("ScreenTimeExtension.entitlements", None), ".monitor", True),
]
DISPLAY = {
    "PuppyPomodoro": "Puppy Pomodoro",
    "PorkWidget": "Pork's clock",
    "PorkShieldConfig": "Pork's blocked-app screen",
    "PorkShieldAction": "Pork's blocked-app buttons",
    "PorkMonitor": "Pork's break watcher",
}


def project(lite):
    name = "PuppyPomodoroLite" if lite else "PuppyPomodoro"
    exts = [e for e in EXTENSIONS if not (lite and e[5])]
    targets = [APP] + exts
    o = {}
    P = lambda *a: oid(name, *a)

    proj, main, products = P("project"), P("main"), P("products")
    folders = []
    for t in targets:
        for f in t[1]:
            if f not in folders:
                folders.append(f)
    for f in folders:
        o[P("folder", f)] = {
            "isa": "PBXFileSystemSynchronizedRootGroup",
            "explicitFileTypes": {},
            "explicitFolders": [],
            "path": f,
            "sourceTree": "<group>",
        }
    for t in targets:
        is_app = t is APP
        o[P("product", t[0])] = {
            "isa": "PBXFileReference",
            "explicitFileType": "wrapper.application" if is_app else "wrapper.app-extension",
            "includeInIndex": "0",
            "path": t[0] + (".app" if is_app else ".appex"),
            "sourceTree": "BUILT_PRODUCTS_DIR",
        }
    o[products] = {"isa": "PBXGroup", "children": [P("product", t[0]) for t in targets],
                   "name": "Products", "sourceTree": "<group>"}
    o[main] = {"isa": "PBXGroup", "children": [P("folder", f) for f in folders] + [products],
               "sourceTree": "<group>"}

    def configs(owner, debug, release):
        d, r, lst = P("cfg", owner, "Debug"), P("cfg", owner, "Release"), P("cfglist", owner)
        o[d] = {"isa": "XCBuildConfiguration", "buildSettings": debug, "name": "Debug"}
        o[r] = {"isa": "XCBuildConfiguration", "buildSettings": release, "name": "Release"}
        o[lst] = {"isa": "XCConfigurationList", "buildConfigurations": [d, r],
                  "defaultConfigurationIsVisible": "0", "defaultConfigurationName": "Release"}
        return lst

    embed_files, deps = [], []
    for t in targets:
        tname, tfolders, plist, ents, suffix, _ = t
        is_app = t is APP
        ent = ents[1] if lite else ents[0]
        phases = []
        for kind in ("Sources", "Frameworks", "Resources"):
            pid = P("phase", tname, kind)
            o[pid] = {"isa": f"PBX{kind}BuildPhase", "buildActionMask": "2147483647",
                      "files": [], "runOnlyForDeploymentPostprocessing": "0"}
            phases.append(pid)
        if is_app:
            embed = P("phase", tname, "Embed")
            phases.append(embed)
        s = {
            "CODE_SIGN_ENTITLEMENTS": "Config/" + ent,
            "CODE_SIGN_STYLE": "Automatic",
            "CURRENT_PROJECT_VERSION": "1",
            "GENERATE_INFOPLIST_FILE": "YES",
            "INFOPLIST_FILE": "Config/" + plist,
            "INFOPLIST_KEY_CFBundleDisplayName": DISPLAY[tname],
            "INFOPLIST_KEY_NSHumanReadableCopyright": "",
            "MARKETING_VERSION": VERSION,
            "PRODUCT_BUNDLE_IDENTIFIER": "$(PORK_ID_PREFIX)" + suffix,
            "PRODUCT_NAME": "$(TARGET_NAME)",
            "SWIFT_EMIT_LOC_STRINGS": "YES",
            "SWIFT_VERSION": "5.0",
            "TARGETED_DEVICE_FAMILY": "1",
        }
        if is_app:
            s.update({
                "ASSETCATALOG_COMPILER_APPICON_NAME": "AppIcon",
                "ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME": "AccentColor",
                "ENABLE_PREVIEWS": "YES",
                "INFOPLIST_KEY_UIApplicationSceneManifest_Generation": "YES",
                "INFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents": "YES",
                "INFOPLIST_KEY_UILaunchScreen_Generation": "YES",
                "INFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone": "UIInterfaceOrientationPortrait",
                "LD_RUNPATH_SEARCH_PATHS": ["$(inherited)", "@executable_path/Frameworks"],
            })
        else:
            s.update({
                "LD_RUNPATH_SEARCH_PATHS": ["$(inherited)", "@executable_path/Frameworks",
                                            "@executable_path/../../Frameworks"],
                "SKIP_INSTALL": "YES",
            })
        tid = P("target", tname)
        o[tid] = {
            "isa": "PBXNativeTarget",
            "buildConfigurationList": configs(tname, dict(s), dict(s)),
            "buildPhases": phases,
            "buildRules": [],
            "dependencies": [],
            "fileSystemSynchronizedGroups": [P("folder", f) for f in tfolders],
            "name": tname,
            "packageProductDependencies": [],
            "productName": tname,
            "productReference": P("product", tname),
            "productType": "com.apple.product-type.application" if is_app
            else "com.apple.product-type.app-extension",
        }
        if not is_app:
            bf, proxy, dep = P("embedfile", tname), P("proxy", tname), P("dep", tname)
            o[bf] = {"isa": "PBXBuildFile", "fileRef": P("product", tname),
                     "settings": {"ATTRIBUTES": ["RemoveHeadersOnCopy"]}}
            o[proxy] = {"isa": "PBXContainerItemProxy", "containerPortal": proj, "proxyType": "1",
                        "remoteGlobalIDString": tid, "remoteInfo": tname}
            o[dep] = {"isa": "PBXTargetDependency", "target": tid, "targetProxy": proxy}
            embed_files.append(bf)
            deps.append(dep)

    app_t = P("target", APP[0])
    o[app_t]["dependencies"] = deps
    o[P("phase", APP[0], "Embed")] = {
        "isa": "PBXCopyFilesBuildPhase", "buildActionMask": "2147483647", "dstPath": "",
        "dstSubfolderSpec": "13", "files": embed_files, "name": "Embed Foundation Extensions",
        "runOnlyForDeploymentPostprocessing": "0",
    }

    conditions = "LITE " if lite else ""
    common = {
        "ALWAYS_SEARCH_USER_PATHS": "NO",
        "ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS": "YES",
        "CLANG_ENABLE_MODULES": "YES",
        "CLANG_ENABLE_OBJC_ARC": "YES",
        "ENABLE_STRICT_OBJC_MSGSEND": "YES",
        "ENABLE_USER_SCRIPT_SANDBOXING": "YES",
        "GCC_C_LANGUAGE_STANDARD": "gnu17",
        "IPHONEOS_DEPLOYMENT_TARGET": "17.0",
        "PORK_ID_PREFIX": ID_PREFIX,
        "SDKROOT": "iphoneos",
        "SWIFT_VERSION": "5.0",
    }
    debug = dict(common, **{
        "COPY_PHASE_STRIP": "NO",
        "DEBUG_INFORMATION_FORMAT": "dwarf",
        "ENABLE_TESTABILITY": "YES",
        "GCC_DYNAMIC_NO_PIC": "NO",
        "GCC_OPTIMIZATION_LEVEL": "0",
        "GCC_PREPROCESSOR_DEFINITIONS": ["DEBUG=1", "$(inherited)"],
        "ONLY_ACTIVE_ARCH": "YES",
        "SWIFT_ACTIVE_COMPILATION_CONDITIONS": f"DEBUG {conditions}$(inherited)",
        "SWIFT_OPTIMIZATION_LEVEL": "-Onone",
    })
    release = dict(common, **{
        "COPY_PHASE_STRIP": "NO",
        "DEBUG_INFORMATION_FORMAT": "dwarf-with-dsym",
        "ENABLE_NS_ASSERTIONS": "NO",
        "SWIFT_ACTIVE_COMPILATION_CONDITIONS": f"{conditions}$(inherited)",
        "SWIFT_COMPILATION_MODE": "wholemodule",
        "VALIDATE_PRODUCT": "YES",
    })
    o[proj] = {
        "isa": "PBXProject",
        "attributes": {
            "BuildIndependentTargetsInParallel": "1",
            "LastSwiftUpdateCheck": "1600",
            "LastUpgradeCheck": "1600",
            "TargetAttributes": {P("target", t[0]): {"CreatedOnToolsVersion": "16.0"} for t in targets},
        },
        "buildConfigurationList": configs("project", debug, release),
        "developmentRegion": "en",
        "hasScannedForEncodings": "0",
        "knownRegions": ["en", "Base"],
        "mainGroup": main,
        "minimizedProjectReferenceProxies": "1",
        "preferredProjectObjectVersion": "77",
        "productRefGroup": products,
        "projectDirPath": "",
        "projectRoot": "",
        "targets": [P("target", t[0]) for t in targets],
    }

    # Sections in the order Xcode writes them.
    order = ["PBXBuildFile", "PBXContainerItemProxy", "PBXCopyFilesBuildPhase", "PBXFileReference",
             "PBXFileSystemSynchronizedRootGroup", "PBXFrameworksBuildPhase", "PBXGroup",
             "PBXNativeTarget", "PBXProject", "PBXResourcesBuildPhase", "PBXSourcesBuildPhase",
             "PBXTargetDependency", "XCBuildConfiguration", "XCConfigurationList"]
    text = "// !$*UTF8*$!\n{\n\tarchiveVersion = 1;\n\tclasses = {\n\t};\n\tobjectVersion = 77;\n\tobjects = {\n"
    for isa in order:
        items = sorted((k, v) for k, v in o.items() if v["isa"] == isa)
        if not items:
            continue
        text += f"\n/* Begin {isa} section */\n"
        for k, v in items:
            text += f"\t\t{k} = {dump(v, 2)};\n"
        text += f"/* End {isa} section */\n"
    text += f"\t}};\n\trootObject = {proj};\n}}\n"

    out = ROOT / f"{name}.xcodeproj"
    out.mkdir(exist_ok=True)
    (out / "project.pbxproj").write_text(text)
    print("wrote", out.name)


project(lite=False)
project(lite=True)
