#!/usr/bin/env python3
"""Preview-only delivery. Sandbox paths are injectable only by imported tests."""
import hashlib
import json
import os
from pathlib import Path
import plistlib
import shutil
import signal
import subprocess
import sys
import time
import uuid
from urllib.parse import urlparse

PREVIEW_ID = 'app.notchmuse.mac.preview'
INSTALLED = Path('/Applications/NotchMuse Preview.app')
STABLE = Path('/Applications/NotchMuse.app')
PREFERENCES = Path.home() / 'Library/Preferences/app.notchmuse.mac.plist'


def info(app):
    if app.is_symlink() or app.resolve() == STABLE.resolve():
        raise ValueError('Refusing a symlink or Stable app')
    with (app / 'Contents/Info.plist').open('rb') as handle:
        data = plistlib.load(handle)
    if data.get('CFBundleIdentifier') != PREVIEW_ID or data.get('NotchMusePreview') is not True:
        raise ValueError('Expected isolated Preview bundle')
    build = str(data.get('CFBundleVersion', ''))
    if not build.isascii() or not build.isdigit() or int(build) < 1:
        raise ValueError('Preview build must be a positive integer')
    if data.get('CFBundleExecutable') != 'NotchMuse':
        raise ValueError('Unexpected Preview executable')
    return data


def next_build(requested='', installed=INSTALLED):
    current = int(info(installed)['CFBundleVersion']) if installed.exists() else 0
    build = requested or str(current + 1)
    if not build.isascii() or not build.isdigit() or int(build) <= current:
        raise ValueError(f'Preview build must exceed installed build {current}')
    return str(int(build))


def verify(app, build):
    data = info(app)
    if str(data['CFBundleVersion']) != str(build):
        raise ValueError('Packaged build differs from requested build')
    feed = data.get('SUFeedURL', '')
    url = urlparse(feed)
    if feed != 'https://invalid.localhost/appcast.xml' and not (
        url.scheme == 'http' and url.hostname == '127.0.0.1' and url.path == '/appcast.xml'
        and url.port and not url.username and not url.password and not url.query and not url.fragment
    ):
        raise ValueError('Preview must not read a public Sparkle feed')
    if data.get('SUEnableAutomaticChecks') is not False:
        raise ValueError('Preview automatic Sparkle checks must be disabled')
    executable = app / 'Contents/MacOS/NotchMuse'
    if executable.is_symlink() or not os.access(executable, os.X_OK):
        raise ValueError('Missing or unsafe Preview executable')
    subprocess.run(['/usr/bin/codesign', '--verify', '--deep', '--strict', str(app)], check=True)
    return data


def digest(paths):
    result = hashlib.sha256()
    for root in paths:
        result.update(b'ROOT\0')
        if not root.exists():
            result.update(b'ABSENT')
            continue
        for path in sorted(root.rglob('*')) if root.is_dir() else [root]:
            result.update(str(path.relative_to(root) if path != root else path.name).encode())
            if path.is_symlink():
                result.update(os.readlink(path).encode())
            elif path.is_file():
                with path.open('rb') as handle:
                    for chunk in iter(lambda: handle.read(1024 * 1024), b''):
                        result.update(chunk)
    return result.hexdigest()


def copy_app(source, target):
    subprocess.run(['/usr/bin/ditto', str(source), str(target)], check=True)


def comm(pid):
    return subprocess.run(['/bin/ps', '-ww', '-p', str(pid), '-o', 'comm='],
                          capture_output=True, text=True, check=False).stdout.strip()


def preview_pids(app):
    executable = str(app / 'Contents/MacOS/NotchMuse')
    output = subprocess.check_output(['/bin/ps', '-wwaxo', 'pid=,comm='], text=True)
    return [int(parts[0]) for line in output.splitlines()
            if len(parts := line.strip().split(None, 1)) == 2 and parts[1] == executable]


def stop(app, pids):
    executable = str(app / 'Contents/MacOS/NotchMuse')
    for pid in pids:
        if comm(pid) != executable:
            raise RuntimeError(f'Refusing SIGTERM: PID {pid} no longer owns Preview executable')
        os.kill(pid, signal.SIGTERM)
    deadline = time.monotonic() + 8
    while any(comm(pid) == executable for pid in pids):
        if time.monotonic() >= deadline:
            raise RuntimeError('Preview did not terminate; installation refused')
        time.sleep(.1)


def start(app, log):
    with log.open('ab') as handle:
        process = subprocess.Popen([str(app / 'Contents/MacOS/NotchMuse')],
                                   stdout=handle, stderr=handle, start_new_session=True)
    time.sleep(3)
    if process.poll() is not None or comm(process.pid) != str(app / 'Contents/MacOS/NotchMuse'):
        raise RuntimeError('New Preview failed startup verification')
    return process.pid


def export_preferences(path):
    result = subprocess.run(['/usr/bin/defaults', 'export', PREVIEW_ID, str(path)],
                            capture_output=True, check=False)
    if result.returncode:
        preview_file = Path.home() / f'Library/Preferences/{PREVIEW_ID}.plist'
        if preview_file.exists():
            raise RuntimeError('Cannot export existing Preview preferences')
        return False
    path.chmod(0o600)
    return True


def restore_preferences(path, existed):
    args = ['import', PREVIEW_ID, str(path)] if existed else ['delete', PREVIEW_ID]
    result = subprocess.run(['/usr/bin/defaults', *args], capture_output=True, check=False)
    if existed and result.returncode:
        raise RuntimeError('Could not restore Preview preferences')


def deliver(candidate, output, build, installed=INSTALLED, stable=STABLE, preferences=PREFERENCES, expected_stable=None):
    if installed.name != 'NotchMuse Preview.app' or installed.is_symlink():
        raise ValueError('Install destination must be a real Preview app path')
    if installed.resolve() == stable.resolve() or candidate.resolve() == installed.resolve():
        raise ValueError('Unsafe candidate or destination')
    next_build(str(build), installed)
    verify(candidate, build)  # No process is touched before package validation.
    output.mkdir(parents=True, exist_ok=True)
    stable_before = digest([stable, preferences])
    if expected_stable is not None and stable_before != expected_stable:
        raise RuntimeError('Stable changed externally during build; installation refused')
    size = sum(p.stat().st_size for p in candidate.rglob('*') if p.is_file())
    old_size = sum(p.stat().st_size for p in installed.rglob('*') if p.is_file()) if installed.exists() else 0
    if shutil.disk_usage(installed.parent).free < size * 2 + old_size + 64 * 1024 * 1024:
        raise RuntimeError('Insufficient free disk space for staging and rollback')
    if shutil.disk_usage(output).free < old_size + 64 * 1024 * 1024:
        raise RuntimeError('Insufficient free disk space for rollback storage')
    previous = info(installed)['CFBundleVersion'] if installed.exists() else None
    token = uuid.uuid4().hex[:12]
    backup = output.parent / 'preview-rollbacks' / f'preview{previous or "none"}-{token}'
    backup.mkdir(parents=True, mode=0o700)
    rollback = backup / f'NotchMuse Preview{previous}.app'
    if previous is not None:
        copy_app(installed, rollback)
        verify(rollback, previous)
        if digest([installed]) != digest([rollback]):
            raise RuntimeError('Rollback copy differs from installed Preview')
    pref_file = backup / 'preferences.plist'
    prefs_existed = export_preferences(pref_file)
    manifest = {'rollback_build': previous, 'app': str(rollback) if previous else None,
                'preferences_exported': prefs_existed, 'preferences': str(pref_file)}
    (backup / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
    staged = installed.parent / f'.NotchMuse Preview.stage-{token}.app'
    displaced = installed.parent / f'.NotchMuse Preview.previous-{token}.app'
    pids = []
    stopped = moved = new_installed = False
    try:
        copy_app(candidate, staged)
        verify(staged, build)
        if digest([candidate]) != digest([staged]):
            raise RuntimeError('Staged app differs from verified candidate')
        if digest([stable, preferences]) != stable_before:
            raise RuntimeError('Stable changed externally during preparation; installation refused')
        pids = preview_pids(installed)
        stopped = bool(pids)  # A partial SIGTERM failure can still stop an old instance.
        stop(installed, pids)
        if installed.exists():
            installed.rename(displaced)
            moved = True
        staged.rename(installed)
        new_installed = True
        pid = start(installed, output / 'preview-runtime.log')
        actual = verify(installed, build)['CFBundleVersion']
        if digest([stable, preferences]) != stable_before:
            raise RuntimeError('Stable hash changed externally during delivery')
        report = {'preview_build': actual, 'installed': str(installed), 'running_pid': pid,
                  **manifest, 'stable_unchanged': True, 'stable_sha256': stable_before}
        (output / 'last-delivery.json').write_text(json.dumps(report, indent=2) + '\n')
        if moved:
            try:
                shutil.rmtree(displaced)
            except OSError:
                # The verified rollback remains complete even if old-path cleanup fails.
                print(f'Previous path cleanup incomplete: {displaced}', file=sys.stderr)
        return report
    except Exception as error:
        restored_pid = None
        restore_error = None
        try:
            if new_installed:
                stop(installed, preview_pids(installed))
                shutil.rmtree(installed)
            if moved:
                displaced.rename(installed)
            if stopped or new_installed:
                restore_preferences(pref_file, prefs_existed)
            if stopped and previous is not None and not preview_pids(installed):
                restored_pid = start(installed, output / 'preview-runtime.log')
        except Exception as restore_failure:
            restore_error = str(restore_failure)
        failure = {'error': str(error), 'restored_previous_build': previous if installed.exists() and not restore_error else None,
                   'restored_pid': restored_pid, 'restore_error': restore_error,
                   'stable_unchanged': digest([stable, preferences]) == stable_before, **manifest}
        (output / 'last-delivery-failure.json').write_text(json.dumps(failure, indent=2) + '\n')
        raise RuntimeError(f'Delivery failed: {error}; previous restore: {restore_error or "complete"}; rollback: {backup}') from error
    finally:
        if staged.exists():
            shutil.rmtree(staged)


def main():
    command = sys.argv[1]
    if command == 'next-build':
        print(next_build(sys.argv[2] if len(sys.argv) > 2 else ''))
    elif command == 'stable-hash':
        print(digest([STABLE, PREFERENCES]))
    elif command == 'verify-stable':
        if digest([STABLE, PREFERENCES]) != sys.argv[2]:
            raise RuntimeError('Stable changed externally during build')
    elif command == 'verify':
        verify(Path(sys.argv[2]), sys.argv[3])
    elif command == 'deliver':
        report = deliver(Path(sys.argv[2]), Path(sys.argv[3]), sys.argv[4], expected_stable=sys.argv[5] if len(sys.argv) > 5 else None)
        print(f'Preview Build: {report["preview_build"]}\nInstalled: {report["installed"]}\n'
              f'Running: YES (PID {report["running_pid"]})\nRollback Build: {report["rollback_build"]}\n'
              f'Stable unchanged: {"YES" if report["stable_unchanged"] else "NO"}')
    else:
        raise ValueError('Unknown lifecycle command')


if __name__ == '__main__':
    try:
        main()
    except Exception as error:
        print(str(error), file=sys.stderr)
        sys.exit(1)
