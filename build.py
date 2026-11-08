"""Package the checked Succubus Plus resource snapshot with LSLib Divine."""
import argparse
import hashlib
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parent
SOURCE = ROOT / 'package_source'


def inventory(root):
    return {p.relative_to(root).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest()
            for p in root.rglob('*') if p.is_file()}


def run(divine, *args):
    result = subprocess.run([str(divine), '-g', 'bg3', *map(str, args)],
                            capture_output=True, text=True, errors='replace')
    if result.returncode or '[FATAL]' in result.stdout + result.stderr:
        raise RuntimeError(result.stdout + '\n' + result.stderr)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--divine', type=Path, required=True, help='Path to LSLib Divine executable')
    parser.add_argument('--output', type=Path, default=ROOT / 'build' / 'SuccubusPlus.pak')
    args = parser.parse_args()
    divine = args.divine.resolve()
    output = args.output.resolve()
    if not divine.is_file():
        parser.error(f'Divine not found: {divine}')
    if not SOURCE.is_dir():
        parser.error(f'Package resource snapshot missing: {SOURCE}')
    if output.exists():
        parser.error(f'Output already exists: {output}')
    if SOURCE.resolve() in output.parents:
        parser.error('Output cannot be placed inside the package source')
    output.parent.mkdir(parents=True, exist_ok=True)
    before = inventory(SOURCE)
    if not before:
        raise RuntimeError('Package resource snapshot is empty')
    with tempfile.TemporaryDirectory(prefix='succubus-build-', dir=output.parent) as tmp:
        tmp = Path(tmp)
        packed = tmp / 'SuccubusPlus.pak'
        extracted = tmp / 'extracted'
        run(divine, '-a', 'create-package', '-s', SOURCE, '-d', packed, '-c', 'lz4')
        run(divine, '-a', 'extract-package', '-s', packed, '-d', extracted)
        if inventory(extracted) != before or inventory(SOURCE) != before:
            raise RuntimeError('Package verification failed: resources differ from source')
        packed.rename(output)
    print(f'Created and verified: {output}')
    print('SHA256:', hashlib.sha256(output.read_bytes()).hexdigest())


if __name__ == '__main__':
    main()
