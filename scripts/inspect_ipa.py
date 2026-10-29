"""Validate the supplied thin arm64 IPA before and after injection."""
import argparse
import hashlib
import plistlib
import struct
import zipfile
from pathlib import Path

INPUT_SHA256 = '9399201c85b5ec7747ac12870678abc938251470a5ea8476e8c9c9caa18e58eb'


def inspect(path, is_input=False, is_output=False, extract=None):
    with zipfile.ZipFile(path) as archive:
        names = archive.namelist()
        roots = [n[:-10] for n in names if n.startswith('Payload/')
                 and n.count('/') == 2 and n.endswith('/Info.plist')]
        if len(roots) != 1:
            raise ValueError('Expected exactly one main app')
        root = roots[0]
        info = plistlib.loads(archive.read(root + 'Info.plist'))
        print({k: info.get(k) for k in ('CFBundleIdentifier',
              'CFBundleShortVersionString', 'MinimumOSVersion')})
        if info['CFBundleShortVersionString'] != '21.43.5':
            raise ValueError('Unexpected YouTube version')
        encrypted = []
        loads = []
        with archive.open(root + info['CFBundleExecutable']) as binary:
            header = binary.read(32)
            if struct.unpack_from('<I', header)[0] != 0xFEEDFACF:
                raise ValueError('Expected thin little-endian 64-bit Mach-O')
            for _ in range(struct.unpack_from('<I', header, 16)[0]):
                command, size = struct.unpack('<II', binary.read(8))
                if size < 8 or size > 1024 * 1024:
                    raise ValueError('Invalid load command')
                payload = binary.read(size - 8)
                if command in (0x21, 0x2C):
                    encrypted.append(struct.unpack_from('<III', payload)[2])
                if (command & 0x7FFFFFFF) in (0xC, 0x18, 0x1F):
                    offset = struct.unpack_from('<I', payload)[0] - 8
                    loads.append(payload[offset:].split(b'\0')[0].decode())
        print('Encryption identifiers:', encrypted)
        if not encrypted or any(encrypted):
            raise ValueError('Main executable is not marked decrypted')
        for name in loads:
            if name.startswith('@rpath/'):
                print('Embedded dependency:', name)
                if root + 'Frameworks/' + name[7:] not in names:
                    raise ValueError('Missing embedded dependency: ' + name)
        if is_output:
            for lib in ('uYou.dylib', 'uYouPlus.dylib', 'YouTubeX.dylib'):
                if root + 'Frameworks/' + lib not in names:
                    raise ValueError('Missing injected library: ' + lib)
                if not any(n.endswith('/' + lib) for n in loads):
                    raise ValueError('Missing main executable load command: ' + lib)
        if is_input:
            with open(path, 'rb') as stream:
                digest = hashlib.file_digest(stream, 'sha256').hexdigest()
            if digest != INPUT_SHA256:
                raise ValueError('Input does not match the supplied local IPA')
        if extract:
            destination = Path(extract).resolve()
            for name in names:
                target = (destination / name).resolve()
                if not target.is_relative_to(destination):
                    raise ValueError('Unsafe archive path')
            archive.extractall(destination)
    print('Static IPA checks passed; device compatibility still requires testing.')


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('ipa')
    parser.add_argument('--input', action='store_true')
    parser.add_argument('--output', action='store_true')
    parser.add_argument('--extract')
    args = parser.parse_args()
    inspect(args.ipa, args.input, args.output, args.extract)
