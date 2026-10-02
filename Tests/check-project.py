from pathlib import Path
import re, plistlib, sys
project=Path('FIELD iOS.xcodeproj/project.pbxproj').read_text()
files=list(Path('FIELD iOS').rglob('*.swift'))
missing=[str(p) for p in files if len(re.findall(r'path = "?'+re.escape(p.name)+r'"?;',project))!=1]
if missing: sys.exit('ERROR: Swift files missing or duplicate Xcode file refs '+str(missing))
source_section=project.split('/* Begin PBXSourcesBuildPhase section */')[1].split('/* End PBXSourcesBuildPhase section */')[0]
with_sources=set(re.findall(r'A300000000000000000000[0-9A-F]{2}',source_section))
expected=set(re.findall(r'(A300000000000000000000[0-9A-F]{2}) /\* .* in Sources \*/ =',project))
if with_sources!=expected: sys.exit('ERROR: unassigned/duplicate Source build phase refs '+str(with_sources^expected))
assert 'https://github.com/maplibre/maplibre-gl-native-distribution' in project
assert 'J30000000000000000000001' in project
# Both app configurations must search the framework directory. MapLibre is an
# SPM dynamic xcframework and a build can pass but the simulator can SIGABRT
# during dyld linking when these @rpath entries are absent.
for config_id in ("G30000000000000000000001", "G30000000000000000000002"):
    marker = config_id + " = {isa = XCBuildConfiguration; buildSettings = {"
    begin = project.find(marker)
    assert begin >= 0, f'Cannot locate app build config {config_id}'
    finish = project.index("}; name = ", begin)
    settings = project[begin:finish]
    assert 'LD_RUNPATH_SEARCH_PATHS' in settings
    assert '@executable_path/Frameworks' in settings
    assert '@loader_path/Frameworks' in settings

with Path('FIELD iOS/Resources/Info.plist').open('rb') as stream: info=plistlib.load(stream)
assert info['CFBundleShortVersionString']=='0.8' and info['CFBundleVersion']=='8'
for required_key in ('NSLocationWhenInUseUsageDescription', 'NSBluetoothAlwaysUsageDescription', 'NSMotionUsageDescription'):
    assert info.get(required_key), f'Missing iOS privacy description: {required_key}'
print(f'PASS: all {len(files)} Swift files uniquely present in Xcode, MapLibre SPM product linked, Info.plist version 0.8')
