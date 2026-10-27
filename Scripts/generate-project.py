#!/usr/bin/env python3
"""Deterministic Xcode project generation using only Python's standard library."""
from pathlib import Path
import hashlib
import json
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parent.parent
objects = {}

def oid(name):
    return hashlib.sha256(name.encode()).hexdigest()[:24].upper()

def add(object_name, **values):
    key = oid(object_name)
    objects[key] = values
    return key

def configurations(name, settings):
    configs = []
    for mode in ("Debug", "Release"):
        values = dict(settings)
        values["SWIFT_OPTIMIZATION_LEVEL"] = "-Onone" if mode == "Debug" else "-O"
        values["SWIFT_COMPILATION_MODE"] = "singlefile" if mode == "Debug" else "wholemodule"
        values["DEBUG_INFORMATION_FORMAT"] = "dwarf" if mode == "Debug" else "dwarf-with-dsym"
        configs.append(add(name+mode, isa="XCBuildConfiguration", buildSettings=values, name=mode))
    return add(name+"ConfigList", isa="XCConfigurationList", buildConfigurations=configs,
               defaultConfigurationIsVisible=0, defaultConfigurationName="Release")

products = []
groups = []
package = add("LocalPackage", isa="XCLocalSwiftPackageReference", relativePath=".")
targets = []
target_ids = {}
common = {
    "ARCHS": "arm64", "MACOSX_DEPLOYMENT_TARGET": "26.0", "SDKROOT": "macosx",
    "SWIFT_VERSION": "6.0", "SWIFT_STRICT_CONCURRENCY": "complete",
    "ENABLE_HARDENED_RUNTIME": "YES", "ENABLE_APP_SANDBOX": "NO",
    "CODE_SIGN_STYLE": "Automatic", "DEVELOPMENT_TEAM": "",
    "SWIFT_EMIT_LOC_STRINGS": "YES", "CLANG_WARN_DOCUMENTATION_COMMENTS": "YES",
    "GCC_WARN_INHIBIT_ALL_WARNINGS": "NO", "SWIFT_TREAT_WARNINGS_AS_ERRORS": "YES",
    "GENERATE_INFOPLIST_FILE": "YES", "CURRENT_PROJECT_VERSION": "1", "MARKETING_VERSION": "0.1.0",
}

specs = [
    ("Memoria", "App", "com.apple.product-type.application", "wrapper.application", "Memoria.app",
     ["MemoriaCore", "MemoriaCollectors", "MemoriaServices", "MemoriaWidgetSupport"]),
    ("MemoriaHelper", "Helper", "com.apple.product-type.tool", "compiled.mach-o.executable", "MemoriaHelper", ["MemoriaServices"]),
    ("MemoriaFixture", "Fixtures", "com.apple.product-type.tool", "compiled.mach-o.executable", "MemoriaFixture", []),
    ("MemoriaWidget", "Widget", "com.apple.product-type.app-extension", "wrapper.app-extension", "MemoriaWidget.appex", ["MemoriaWidgetSupport"]),
    ("MemoriaUITests", "UITests", "com.apple.product-type.bundle.ui-testing", "wrapper.cfbundle", "MemoriaUITests.xctest", []),
]
for name, folder, product_type, file_type, product_name, dependencies in specs:
    files = []
    builds = []
    for path in sorted((ROOT/folder).glob("*.swift")):
        file = add("file:"+str(path.relative_to(ROOT)), isa="PBXFileReference", lastKnownFileType="sourcecode.swift",
                   path=path.name, sourceTree="<group>")
        files.append(file)
        builds.append(add("build:"+str(path.relative_to(ROOT)), isa="PBXBuildFile", fileRef=file))
    groups.append(add("group:"+folder, isa="PBXGroup", children=files, path=folder, sourceTree="<group>"))
    sources = add(name+"Sources", isa="PBXSourcesBuildPhase", buildActionMask=2147483647, files=builds,
                  runOnlyForDeploymentPostprocessing=0)
    package_products = []
    linked = []
    for dependency in dependencies:
        ref = add(name+"Package"+dependency, isa="XCSwiftPackageProductDependency", productName=dependency)
        package_products.append(ref)
        linked.append(add(name+"Link"+dependency, isa="PBXBuildFile", productRef=ref))
    frameworks = add(name+"Frameworks", isa="PBXFrameworksBuildPhase", buildActionMask=2147483647,
                     files=linked, runOnlyForDeploymentPostprocessing=0)
    product = add(name+"Product", isa="PBXFileReference", explicitFileType=file_type, includeInIndex=0,
                  path=product_name, sourceTree="BUILT_PRODUCTS_DIR")
    products.append(product)
    settings = dict(common)
    settings.update(PRODUCT_NAME=name, PRODUCT_BUNDLE_IDENTIFIER={
        "Memoria":"fyi.trentini.memoria", "MemoriaHelper":"fyi.trentini.memoria.helper",
        "MemoriaFixture":"fyi.trentini.memoria.fixture", "MemoriaUITests":"fyi.trentini.memoria.uitests",
        "MemoriaWidget":"fyi.trentini.memoria.widget"
    }[name])
    settings["INFOPLIST_KEY_MemoriaSigningTeam"] = "$(DEVELOPMENT_TEAM)"
    settings["LD_RUNPATH_SEARCH_PATHS"] = ["$(inherited)", "@executable_path/../Frameworks"]
    if name == "Memoria":
        settings.update(ASSETCATALOG_COMPILER_APPICON_NAME="Memoria",GENERATE_INFOPLIST_FILE="NO",INFOPLIST_FILE="Configuration/Memoria-Info.plist",CODE_SIGN_ENTITLEMENTS="Configuration/Memoria.entitlements",INFOPLIST_KEY_LSApplicationCategoryType="public.app-category.utilities",
                        INFOPLIST_KEY_NSPrincipalClass="NSApplication",
                        INFOPLIST_KEY_NSHumanReadableCopyright="Copyright © 2026 Bruno Trentini")
    elif name == "MemoriaWidget":
        settings.update(GENERATE_INFOPLIST_FILE="NO",INFOPLIST_FILE="Configuration/MemoriaWidget-Info.plist",
                        CODE_SIGN_ENTITLEMENTS="Configuration/MemoriaWidget.entitlements",ENABLE_APP_SANDBOX="YES",
                        APPLICATION_EXTENSION_API_ONLY="YES",SKIP_INSTALL="YES")
        settings["LD_RUNPATH_SEARCH_PATHS"] = ["$(inherited)","@executable_path/../Frameworks","@executable_path/../../../../Frameworks"]
    elif name == "MemoriaHelper":
        settings["CREATE_INFOPLIST_SECTION_IN_BINARY"] = "YES"
    elif name == "MemoriaUITests":
        settings.update(TEST_TARGET_NAME="Memoria", CODE_SIGNING_ALLOWED="NO")
    configs = configurations(name, settings)
    target = add(name+"Target", isa="PBXNativeTarget", buildConfigurationList=configs,
                 buildPhases=[sources, frameworks], buildRules=[], dependencies=[], name=name,
                 packageProductDependencies=package_products, productName=name,
                 productReference=product, productType=product_type)
    targets.append(target)
    target_ids[name] = target

# Icon Composer supplies the modern app icon. Template PNGs are shared by the
# app and widget; only the app compiles the icon document.
icon_ref=add("BrandIcon",isa="PBXFileReference",lastKnownFileType="folder.iconcomposer.icon",path="Branding/Memoria.icon",sourceTree="<group>")
template_refs=[add("BrandTemplate"+name,isa="PBXFileReference",lastKnownFileType="image.png",path="App/Resources/"+name,sourceTree="<group>") for name in ["BrainTemplate.png","BrainTemplate@2x.png","BrainMark.png","BrainMark@2x.png"]]
groups.append(add("BrandAssetsGroup",isa="PBXGroup",children=[icon_ref,*template_refs],name="Brand assets",sourceTree="<group>"))
for name in ["Memoria","MemoriaWidget"]:
    files=[add(name+"BrandResource"+ref,isa="PBXBuildFile",fileRef=ref) for ref in template_refs+([icon_ref] if name=="Memoria" else [])]
    phase=add(name+"Resources",isa="PBXResourcesBuildPhase",buildActionMask=2147483647,files=files,runOnlyForDeploymentPostprocessing=0)
    objects[target_ids[name]]["buildPhases"].append(phase)

# Bundle the optional helper, but do not register or run it on application launch.
proxy = add("HelperProxy", isa="PBXContainerItemProxy", containerPortal=oid("Project"), proxyType=1,
            remoteGlobalIDString=target_ids["MemoriaHelper"], remoteInfo="MemoriaHelper")
dep = add("HelperDependency", isa="PBXTargetDependency", target=target_ids["MemoriaHelper"], targetProxy=proxy)
objects[target_ids["Memoria"]]["dependencies"] = [dep]
helper_build = add("EmbedHelperBuild", isa="PBXBuildFile", fileRef=oid("MemoriaHelperProduct"),
                   settings={"ATTRIBUTES":["CodeSignOnCopy"]})
embed = add("EmbedHelper", isa="PBXCopyFilesBuildPhase", buildActionMask=2147483647,
            dstPath="", dstSubfolderSpec=6, files=[helper_build], name="Embed Administrator Helper",
            runOnlyForDeploymentPostprocessing=0)
plist_file = add("HelperPlist", isa="PBXFileReference", lastKnownFileType="text.plist.xml",
                 path="Configuration/fyi.trentini.memoria.helper.plist", sourceTree="<group>")
plist_build = add("HelperPlistBuild", isa="PBXBuildFile", fileRef=plist_file)
embed_plist = add("EmbedHelperPlist", isa="PBXCopyFilesBuildPhase", buildActionMask=2147483647,
                  dstPath="Contents/Library/LaunchDaemons", dstSubfolderSpec=1, files=[plist_build],
                  name="Embed Helper Service Definition", runOnlyForDeploymentPostprocessing=0)
objects[target_ids["Memoria"]]["buildPhases"] += [embed, embed_plist]
# The widget is a separate sandboxed extension; no collectors or helper code is linked.
widget_proxy = add("WidgetProxy", isa="PBXContainerItemProxy", containerPortal=oid("Project"), proxyType=1,
                   remoteGlobalIDString=target_ids["MemoriaWidget"], remoteInfo="MemoriaWidget")
widget_dep = add("WidgetDependency", isa="PBXTargetDependency", target=target_ids["MemoriaWidget"], targetProxy=widget_proxy)
objects[target_ids["Memoria"]]["dependencies"].append(widget_dep)
widget_build = add("EmbedWidgetBuild", isa="PBXBuildFile", fileRef=oid("MemoriaWidgetProduct"),
                   settings={"ATTRIBUTES":["CodeSignOnCopy","RemoveHeadersOnCopy"]})
widget_embed = add("EmbedWidget", isa="PBXCopyFilesBuildPhase", buildActionMask=2147483647,
                   dstPath="", dstSubfolderSpec=13, files=[widget_build], name="Embed Widgets",
                   runOnlyForDeploymentPostprocessing=0)
objects[target_ids["Memoria"]]["buildPhases"].append(widget_embed)
ui_proxy = add("UIAppProxy", isa="PBXContainerItemProxy", containerPortal=oid("Project"), proxyType=1,
               remoteGlobalIDString=target_ids["Memoria"], remoteInfo="Memoria")
ui_dep = add("UIAppDependency", isa="PBXTargetDependency", target=target_ids["Memoria"], targetProxy=ui_proxy)
objects[target_ids["MemoriaUITests"]]["dependencies"] = [ui_dep]
product_group = add("Products", isa="PBXGroup", children=products, name="Products", sourceTree="<group>")
main_group = add("MainGroup", isa="PBXGroup", children=groups+[plist_file,product_group], sourceTree="<group>")
project = add("Project", isa="PBXProject", attributes={"LastUpgradeCheck":"2710","BuildIndependentTargetsInParallel":"YES"},
              buildConfigurationList=configurations("Project", common), compatibilityVersion="Xcode 15.0",
              developmentRegion="en", hasScannedForEncodings=0, knownRegions=["en","Base"],
              mainGroup=main_group, productRefGroup=product_group, projectDirPath="", projectRoot="",
              packageReferences=[package], targets=targets)

def serialise(value, indent=0):
    if isinstance(value, dict):
        body = "\n".join("\t"*(indent+1)+json.dumps(str(k))+" = "+serialise(v,indent+1)+";" for k,v in value.items())
        return "{\n"+body+"\n"+"\t"*indent+"}"
    if isinstance(value, list):
        return "("+", ".join(serialise(v,indent) for v in value)+")"
    if isinstance(value, int):
        return str(value)
    return json.dumps(str(value))

project_dir = ROOT/"Memoria.xcodeproj"
project_dir.mkdir(exist_ok=True)
(project_dir/"project.pbxproj").write_text("// !$*UTF8*$!\n"+serialise({
    "archiveVersion":1,"classes":{},"objectVersion":60,"objects":objects,"rootObject":project
})+"\n")

schemes = project_dir/"xcshareddata/xcschemes"
schemes.mkdir(parents=True,exist_ok=True)
for name in ("Memoria","MemoriaHelper","MemoriaFixture"):
    scheme = ET.Element("Scheme", LastUpgradeVersion="2710", version="1.7")
    action = ET.SubElement(scheme,"BuildAction",parallelizeBuildables="YES",buildImplicitDependencies="YES")
    entries = ET.SubElement(action,"BuildActionEntries")
    entry = ET.SubElement(entries,"BuildActionEntry",buildForTesting="YES",buildForRunning="YES",buildForProfiling="YES",buildForArchiving="YES",buildForAnalyzing="YES")
    attrs = dict(BuildableIdentifier="primary",BlueprintIdentifier=target_ids[name],BuildableName=name+".app" if name == "Memoria" else name,BlueprintName=name,ReferencedContainer="container:Memoria.xcodeproj")
    ET.SubElement(entry,"BuildableReference",**attrs)
    test = ET.SubElement(scheme,"TestAction",buildConfiguration="Debug",selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB",selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB",shouldUseLaunchSchemeArgsEnv="YES")
    if name == "Memoria":
        tests = ET.SubElement(test,"Testables")
        testable = ET.SubElement(tests,"TestableReference",skipped="NO")
        ET.SubElement(testable,"BuildableReference",BuildableIdentifier="primary",BlueprintIdentifier=target_ids["MemoriaUITests"],BuildableName="MemoriaUITests.xctest",BlueprintName="MemoriaUITests",ReferencedContainer="container:Memoria.xcodeproj")
    launch = ET.SubElement(scheme,"LaunchAction",buildConfiguration="Debug",selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB",selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB",launchStyle="0",useCustomWorkingDirectory="NO",ignoresPersistentStateOnLaunch="NO",debugDocumentVersioning="YES",debugServiceExtension="internal",allowLocationSimulation="YES")
    ET.SubElement(ET.SubElement(launch,"BuildableProductRunnable",runnableDebuggingMode="0"),"BuildableReference",**attrs)
    ET.SubElement(scheme,"ProfileAction",buildConfiguration="Release",shouldUseLaunchSchemeArgsEnv="YES",savedToolIdentifier="",useCustomWorkingDirectory="NO",debugDocumentVersioning="YES")
    ET.SubElement(scheme,"AnalyzeAction",buildConfiguration="Debug")
    ET.SubElement(scheme,"ArchiveAction",buildConfiguration="Release",revealArchiveInOrganizer="YES")
    ET.indent(scheme)
    ET.ElementTree(scheme).write(schemes/(name+".xcscheme"),encoding="UTF-8",xml_declaration=True)
print("Generated Memoria.xcodeproj and shared schemes.")
