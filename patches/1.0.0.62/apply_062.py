"""Build Succubus Plus .62 locally from the exact .61 PAK and LSLib Divine."""
import argparse
from hashlib import sha256
from pathlib import Path
import subprocess
from tempfile import TemporaryDirectory


BASE_HASH = '2612ac98db7dfd70b7c2ab9f94e48a8e2e03e2539c46e791e2ab016eb3804262'
META = 'Mods/SuccubusPlus/meta.lsx'
STATS = 'Public/SuccubusPlus/Stats/Generated/Data/SuccubusPlus_TemptressRebalance.txt'


def replace_twice(path, old, new):
    source = path.read_bytes()
    if source.count(old) != 2:
        raise ValueError(f'Expected two matches in {path.name}')
    path.write_bytes(source.replace(old, new))


def inventory(tree):
    return {path.relative_to(tree): sha256(path.read_bytes()).digest()
            for path in tree.rglob('*') if path.is_file()}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--divine', required=True, type=Path, help='Path to Divine.exe')
    parser.add_argument('--base', required=True, type=Path, help='Path to the .61 PAK')
    parser.add_argument('--output', default=Path('SuccubusPlus-1.0.0.62.pak'), type=Path)
    args = parser.parse_args()
    divine, base, output = (path.resolve() for path in (args.divine, args.base, args.output))

    try:
        base_data = base.read_bytes()
        if sha256(base_data).hexdigest() != BASE_HASH:
            raise ValueError('The input is not the supported .61 PAK (SHA-256 mismatch)')
        if output.exists():
            raise ValueError(f'Output already exists: {output}')

        def run(action, source, destination, *extra):
            command = [str(divine), '-g', 'bg3', '-a', action, '-s', str(source), '-d', str(destination), *extra]
            result = subprocess.run(command, capture_output=True, text=True, errors='replace')
            if result.returncode or '[FATAL]' in result.stdout + result.stderr:
                raise ValueError(result.stdout + result.stderr)

        with TemporaryDirectory(prefix='succubus-patch-', dir=output.parent) as tmp:
            scratch = Path(tmp)
            staged_base = scratch / 'base.pak'
            staged_base.write_bytes(base_data)
            source = scratch / 'source'
            run('extract-package', staged_base, source)

            prefix = b'data "RequirementConditions" "'
            own_turn = b"HasStatus('SUCC_TM_OWN_TURN',context.Source)"
            temptress = b"HasStatus('SUCC_TM_ENABLED',context.Source) and "
            replace_twice(source / STATS, prefix + own_turn, prefix + temptress + own_turn)
            replace_twice(source / META, b'36028797018964029', b'36028797018964030')

            packed = scratch / 'SuccubusPlus.pak'
            run('create-package', source, packed, '-c', 'lz4')
            check = scratch / 'check'
            run('extract-package', packed, check)
            if inventory(check) != inventory(source):
                raise ValueError('The rebuilt PAK does not match the patched resources')
            packed.rename(output)
        print(f'Created and verified {output}\nSHA-256 {sha256(output.read_bytes()).hexdigest()}')
    except (OSError, ValueError) as exc:
        parser.exit(1, f'{exc}\n')


if __name__ == '__main__':
    main()
