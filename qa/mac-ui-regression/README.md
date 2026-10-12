# Offline Mac reader regression

The user paused BYOK validation on 2026-10-12 at 03:31 UTC
(`Sentinel_16e90e990010819186595583a4bde414`). The explicit manifest
`nonbyok-scope.json` retains **55 GUI methods** and **591 Swift methods**.
Its **18 GUI** and **109 Swift** exclusions are user-excluded and unaccepted;
they never count as passes. BYOK implementation and test functions remain in
source and still compile. This scope does not establish all-73 acceptance.

Two mixed GUI methods keep ordinary assertions. Settings draft checks use the
local provider. The wide conversation method omits its OpenAI-compatible
connection-control prelude; five tasks, Stop/Retry, follow-up, source controls,
copy and explicit saving still use the local in-memory provider. Original mixed
source and earlier failures remain in local evidence and Git history.
`method-inventory.json` retains the original 68 plus 5 inventory unchanged.

Acceptance runs representative6 (including the known EPUB pagination failure),
then the original12 gates plus new5, then the disjoint remaining38 on the same
compiled products and source head. Representatives overlap the final55 and do
not increase its denominator. Each prerequisite must pass exactly, with zero
skips, expected failures or automatic retries. Original test time limits remain
180/240 seconds, and windows remain 1280x800 and 720x520.

`prepare.py` makes a fresh source snapshot, unique bundle and original fixtures.
It never launches an app. Guards deny live HTTP/Keychain access, restrict storage
to its UUID library, and stop input if another app takes the foreground. QA
overlays provide controlled local responses and ownership diagnostics; they do
not create selections or save notes. Production books/notes/apps are not used.

Build with a fresh directory, using the repository heavy-check lock:

```sh
python3 -B qa/mac-ui-regression/nonbyok_scope.py
python3 -B qa/mac-ui-regression/prepare.py --scope nonbyok --output .build/MacFullQA
xcodebuild -project .build/MacFullQA/source/apple/PDFno.xcodeproj \
  -scheme PDFnoMac -configuration Debug -destination 'platform=macOS' \
  -derivedDataPath .build/MacFullQA/DerivedData -jobs 1 \
  -disableAutomaticPackageResolution -skipPackageUpdates build-for-testing \
  CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY=- DEVELOPMENT_TEAM= \
  CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO CODE_SIGN_ENTITLEMENTS=
python3 -B qa/mac-ui-regression/configure.py --qa .build/MacFullQA --scope representative6
python3 -B qa/mac-ui-regression/configure.py --qa .build/MacFullQA --scope nonbyok-gate17
python3 -B qa/mac-ui-regression/configure.py --qa .build/MacFullQA --scope remaining38
```

Native checks uses the approved non-BYOK scope for feature/main pushes and PRs.
Swift execution uses a complete identity allowlist, rather than broad keywords
or whole mixed suites. XML verification requires precisely the retained591,
with no excluded executions. Test-source changes need a classification update.

Actual GUI uses a dedicated GitHub-hosted Mac VM. Do not run tests on the user
desktop without a current handoff. The display helper is restricted to the
repository's disposable runner account and approved refs/events, changing only
the VM login session. It must never configure the user's display.

Run each xctestrun without parallel testing, capturing the actual xcodebuild
exit code. Pass it to `verify-result.py` with --qa, --scope, --result, --log and
--exit-code; the workflow gives complete commands. Keep official result bundles,
logs, exact source/product hashes, and only recorded fixture-window screenshots
under canonical allowlisted paths without symlinks.

Legacy current73/diagnostic scopes remain for historical evidence interpretation;
the workflow does not select them. Re-enabling BYOK validation needs an explicit
scope decision. Offline results do not establish live AI quality or distribution
readiness.
