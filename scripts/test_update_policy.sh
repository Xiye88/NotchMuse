#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
FRAMEWORK="$ROOT/MenuBarLyrics/.build/artifacts/sparkle/Sparkle/Sparkle.xcframework/macos-arm64_x86_64"
TEST_BUILD=$(mktemp -d /tmp/notchmuse-update-policy.XXXXXX)
trap 'rm -rf "$TEST_BUILD"' EXIT
swiftc -parse-as-library -F "$FRAMEWORK" -Xlinker -rpath -Xlinker "$FRAMEWORK" "$ROOT/MenuBarLyrics/Sources/MenuBarLyrics/App/UpdatePolicy.swift" "$ROOT/MenuBarLyrics/Sources/MenuBarLyrics/App/UpdateController.swift" "$ROOT/MenuBarLyrics/Sources/MenuBarLyrics/App/UpdateFeedback.swift" "$ROOT/MenuBarLyrics/Tests/UpdatePolicyTests.swift" -o "$TEST_BUILD/tests"
"$TEST_BUILD/tests"

python3 - "$ROOT/scripts/build_app.sh" <<'PYPLIST'
from pathlib import Path
import os, plistlib, subprocess, sys
source=Path(sys.argv[1]).read_text()
prefix=source.split('APP="$DIST/$APP_NAME.app"',1)[0]
template=source.split('cat > "$CONTENTS/Info.plist" <<PLIST\n',1)[1].split('\nPLIST\n',1)[0]
for preview,feed,enabled in [('1','http://127.0.0.1:1337/appcast.xml',True),('1','https://invalid.localhost/appcast.xml',False),('0','',False)]:
    env=dict(os.environ,NOTCHMUSE_PREVIEW=preview,NOTCHMUSE_PREVIEW_FEED_URL=feed,VERSION='0.8.3',BUILD_NUMBER='71',FEEDBACK_EMAIL='test@example.com')
    result=subprocess.run(['zsh','-c',prefix+'\ncat <<PLIST\n'+template+'\nPLIST\n'],env=env,text=True,capture_output=True,check=True)
    info=plistlib.loads(result.stdout.encode())
    if preview=='1':
        assert info['CFBundleIdentifier']=='app.notchmuse.mac.preview'
        assert info['SUEnableAutomaticChecks']==enabled, (feed,'automatic checks',info['SUEnableAutomaticChecks'])
        assert info['SUAllowsAutomaticUpdates']==enabled
        assert info['SUAutomaticallyUpdate']==enabled
        assert info['SUScheduledCheckInterval']==86400
    else:
        assert info['CFBundleIdentifier']=='app.notchmuse.mac'
        assert info['SUFeedURL']=='https://notchmuse.com/appcast.xml'
        assert info['SUEnableAutomaticChecks'] is True
        assert info['SUAllowsAutomaticUpdates'] is True
        assert info['SUAutomaticallyUpdate'] is True
        assert info['SUScheduledCheckInterval']==86400
    print('PASS plist:',preview,feed or 'Stable default')
PYPLIST
