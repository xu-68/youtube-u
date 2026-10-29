"""Check all bundled arm64 Mach-O dependencies; this is not runtime testing."""
import argparse
import json
import plistlib
import posixpath
import struct
import zipfile

def arm64_slices(data):
    magic = data[:4]
    if magic == b'\xcf\xfa\xed\xfe':
        if struct.unpack_from('<I', data, 4)[0] == 0x100000c:
            yield data
    elif magic == b'\xca\xfe\xba\xbe':
        count = struct.unpack_from('>I', data, 4)[0]
        for index in range(count):
            cpu, _, offset, size, _ = struct.unpack_from('>IIIII', data, 8 + index * 20)
            if cpu == 0x100000c:
                yield data[offset:offset + size]

def inspect(path):
    result = {'scope': 'Static Mach-O dependency and platform checks', 'binaries': [], 'errors': []}
    with zipfile.ZipFile(path) as archive:
        names = set(archive.namelist())
        roots = [name[:-10] for name in names if name.startswith('Payload/') and name.count('/') == 2 and name.endswith('/Info.plist')]
        if len(roots) != 1:
            raise ValueError('Expected one main app')
        root = roots[0]
        info = plistlib.loads(archive.read(root + 'Info.plist'))
        for library in ('uYou', 'uYouPlus', 'YouTubeX', 'iSponsorBlock', 'DontEatMyContent',
                        'YTVideoOverlay', 'YouQuality', 'YouSpeed', 'YouTubeDislikesReturn'):
            if root + 'Frameworks/' + library + '.dylib' not in names:
                result['errors'].append('Missing required plugin: ' + library + '.dylib')
        candidates = [root + info['CFBundleExecutable']]
        candidates += sorted(name for name in names if name.startswith(root + 'Frameworks/') and not name.endswith('/'))
        for name in candidates:
            with archive.open(name) as source:
                magic = source.read(4)
            if magic not in (b'\xcf\xfa\xed\xfe', b'\xca\xfe\xba\xbe'):
                continue
            slices = list(arm64_slices(archive.read(name)))
            if not slices:
                result['errors'].append('No arm64 slice: ' + name)
            for data in slices:
                offset = 32
                dependencies = []
                runpaths = []
                missing = []
                platform = None
                for _ in range(struct.unpack_from('<I', data, 16)[0]):
                    command, size = struct.unpack_from('<II', data, offset)
                    if size < 8 or offset + size > len(data):
                        raise ValueError('Invalid load command: ' + name)
                    if command == 0x32:
                        platform = struct.unpack_from('<I', data, offset + 8)[0]
                    elif command == 0x25:
                        platform = 2
                    if command == 0x8000001c:
                        start = offset + struct.unpack_from('<I', data, offset + 8)[0]
                        runpaths.append(data[start:data.index(b'\0', start, offset + size)].decode())
                    if command & 0x7fffffff in (0xc, 0x18, 0x1f):
                        string_offset = offset + struct.unpack_from('<I', data, offset + 8)[0]
                        dependency = data[string_offset:data.index(b'\0', string_offset, offset + size)].decode()
                        dependencies.append(dependency)
                        target = None
                        if dependency.startswith('@rpath/'):
                            target = root + 'Frameworks/' + dependency[7:]
                        elif dependency.startswith('@loader_path/'):
                            target = posixpath.normpath(posixpath.dirname(name) + '/' + dependency[13:])
                        elif dependency.startswith('@executable_path/'):
                            target = root + dependency[17:]
                        elif not dependency.startswith(('/System/Library/', '/usr/lib/')):
                            result['errors'].append('Unexpected non-system dependency: ' + name + ' -> ' + dependency)
                        if target and target not in names and command & 0x7fffffff != 0x18:
                            missing.append(dependency)
                    offset += size
                for dependency in missing:
                    # Modern iOS supplies the Swift runtime through this explicit search path.
                    if dependency.startswith('@rpath/libswift') and '/usr/lib/swift' in runpaths:
                        continue
                    result['errors'].append('Missing dependency: ' + name + ' -> ' + dependency)
                if platform is not None and platform != 2:
                    result['errors'].append('Not an iOS device binary: ' + name + ' platform=' + str(platform))
                result['binaries'].append({'path': name, 'platform': platform, 'runpaths': runpaths, 'dependencies': dependencies})
    return result

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('ipa')
    parser.add_argument('--report')
    args = parser.parse_args()
    report = inspect(args.ipa)
    if args.report:
        with open(args.report, 'w', encoding='utf-8') as stream:
            json.dump(report, stream, indent=2)
    print('Checked arm64 binary slices:', len(report['binaries']))
    for error in report['errors']:
        print('ERROR:', error)
    raise SystemExit(bool(report['errors']))
