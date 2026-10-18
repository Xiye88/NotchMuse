#!/usr/bin/env python3
"""Run actual delivery file mutations in a temp sandbox, with OS boundaries mocked."""
from contextlib import ExitStack
import json
from pathlib import Path
import plistlib
import shutil
import tempfile
from unittest.mock import patch
import preview_lifecycle as lifecycle


def app(path, build, bundle=lifecycle.PREVIEW_ID):
    (path / 'Contents/MacOS').mkdir(parents=True)
    data = {'CFBundleIdentifier': bundle, 'CFBundleExecutable': 'NotchMuse',
            'CFBundleVersion': str(build), 'NotchMusePreview': True,
            'SUFeedURL': 'https://invalid.localhost/appcast.xml', 'SUEnableAutomaticChecks': False}
    (path / 'Contents/Info.plist').write_bytes(plistlib.dumps(data))
    executable = path / 'Contents/MacOS/NotchMuse'
    executable.write_text(f'sandbox build {build}')
    executable.chmod(0o755)


def refused(function):
    try:
        function()
    except (ValueError, RuntimeError):
        return
    raise AssertionError('Unsafe operation was accepted')


def sandbox(scenario):
    with tempfile.TemporaryDirectory(prefix='notchmuse-preview-guard-') as temp:
        root = Path(temp)
        installed = root / 'Applications/NotchMuse Preview.app'
        stable = root / 'Applications/NotchMuse.app'
        candidate = root / 'candidate/NotchMuse Preview.app'
        output = root / 'dist/preview'
        prefs = root / 'preview.plist'
        stable_prefs = root / 'stable.plist'
        app(installed, 54)
        app(stable, 47, 'app.notchmuse.mac')
        app(candidate, 55)
        prefs.write_bytes(b'original preview preferences')
        stable_prefs.write_bytes(b'stable preferences')
        stable_hash = lifecycle.digest([stable, stable_prefs])
        old_rollback = root / 'dist/preview-rollbacks/previous-53'
        old_rollback.mkdir(parents=True)
        (old_rollback / 'sentinel').write_bytes(b'never replace')
        previous_rollback_hash = lifecycle.digest([old_rollback])
        events = []
        processes = [5400]

        def signed(args, **kwargs):
            assert args[:4] == ['/usr/bin/codesign', '--verify', '--deep', '--strict']
            events.append('verify:' + Path(args[-1]).name)
            if scenario == 'invalid-signature' and Path(args[-1]) == candidate:
                raise RuntimeError('mock invalid signature')

        def copy(source, target):
            if scenario == 'staging-copy-failure' and '.stage-' in target.name:
                raise RuntimeError('mock copy failure')
            shutil.copytree(source, target, symlinks=True)

        def stop(path, pids):
            assert path == installed
            events.append('stop')
            processes.clear()

        def start(path, log):
            events.append('start:' + str(lifecycle.info(path)['CFBundleVersion']))
            if scenario == 'launch-failure' and lifecycle.info(path)['CFBundleVersion'] == '55':
                prefs.write_bytes(b'new app changed preferences')
                raise RuntimeError('mock failed startup')
            processes.append(5500 if lifecycle.info(path)['CFBundleVersion'] == '55' else 5401)
            return processes[-1]

        def export(path):
            shutil.copyfile(prefs, path)
            return True

        def restore(path, existed):
            assert existed
            shutil.copyfile(path, prefs)

        with ExitStack() as stack:
            for name, replacement in [('copy_app', copy), ('stop', stop), ('start', start),
                                      ('preview_pids', lambda _: list(processes)),
                                      ('export_preferences', export), ('restore_preferences', restore)]:
                stack.enter_context(patch.object(lifecycle, name, replacement))
            stack.enter_context(patch.object(lifecycle.subprocess, 'run', signed))
            assert lifecycle.next_build('', installed) == '55'
            refused(lambda: lifecycle.next_build('54', installed))
            refused(lambda: lifecycle.next_build('53', installed))
            refused(lambda: lifecycle.next_build('-1', installed))
            if scenario == 'stable-destination':
                refused(lambda: lifecycle.deliver(candidate, output, '55', stable, stable, stable_prefs))
            elif scenario == 'stable-bundle':
                plist = candidate / 'Contents/Info.plist'
                data = plistlib.loads(plist.read_bytes());data['CFBundleIdentifier'] = 'app.notchmuse.mac'
                plist.write_bytes(plistlib.dumps(data))
                refused(lambda: lifecycle.deliver(candidate, output, '55', installed, stable, stable_prefs))
            elif scenario == 'symlink':
                alias = root / 'alias.app';alias.symlink_to(candidate)
                refused(lambda: lifecycle.deliver(alias, output, '55', installed, stable, stable_prefs))
            elif scenario == 'low-disk':
                stack.enter_context(patch.object(lifecycle.shutil, 'disk_usage', lambda _: shutil._ntuple_diskusage(1, 1, 0)))
                refused(lambda: lifecycle.deliver(candidate, output, '55', installed, stable, stable_prefs))
            elif scenario == 'success':
                report = lifecycle.deliver(candidate, output, '55', installed, stable, stable_prefs)
                assert report['preview_build'] == '55' and report['running_pid'] == 5500
                assert lifecycle.info(Path(report['app']))['CFBundleVersion'] == '54'
                assert Path(report['preferences']).read_bytes() == b'original preview preferences'
                assert events.index('stop') > next(i for i, e in enumerate(events) if '.stage-' in e)
            else:
                refused(lambda: lifecycle.deliver(candidate, output, '55', installed, stable, stable_prefs))
                assert lifecycle.info(installed)['CFBundleVersion'] == '54'
                assert prefs.read_bytes() == b'original preview preferences'
                if scenario == 'launch-failure':
                    assert processes == [5401]
                    failure = json.loads((output / 'last-delivery-failure.json').read_text())
                    assert failure['restored_previous_build'] == '54' and failure['restore_error'] is None
                else:
                    assert 'stop' not in events
        assert lifecycle.digest([stable, stable_prefs]) == stable_hash
        assert lifecycle.digest([old_rollback]) == previous_rollback_hash
        return scenario


if __name__ == '__main__':
    cases = ['success', 'invalid-signature', 'staging-copy-failure', 'launch-failure',
             'stable-destination', 'stable-bundle', 'symlink', 'low-disk']
    for case in cases:
        print('PASS:', sandbox(case))
    with patch.object(lifecycle, 'comm', lambda _: '/Applications/NotchMuse.app/Contents/MacOS/NotchMuse'), \
         patch.object(lifecycle.os, 'kill') as kill:
        refused(lambda: lifecycle.stop(lifecycle.INSTALLED, [4700]))
        kill.assert_not_called()
    print('PASS: PID ownership changed to Stable; no signal sent')
    print('PASS: 9 sandbox lifecycle scenarios; Stable app/preferences and older rollback unchanged')
