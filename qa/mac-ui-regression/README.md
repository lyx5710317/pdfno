# Offline Mac reader regression

This harness compiles the current checkout's original 68 Mac UI methods and the
five accepted reader chrome, conversation and saved-search scenarios. The first
run contains the original 12 gates plus those five scenarios. Only an accepted
17-method result permits the disjoint remaining 56 methods on the same binary.
The method inventory records all three sets.

`prepare.py` creates a new source snapshot, unique bundle and original fixtures.
It never launches an application. The snapshot uses the existing QA guards to
deny real HTTP and Keychain access, constrain storage to its own UUID library,
and stop input when another application takes the foreground. The controlled
offline explanation response lets the Stop scenario exercise real cancellation
and manual retry. Other overlays add ownership and geometry diagnostics; they
do not create selections or save notes for the tests. Production sources in the
checkout are left unchanged by preparation.

Build and configure, using an unused output directory:

```sh
python3 -B qa/mac-ui-regression/prepare.py --output .build/MacFullQA
xcodebuild -project .build/MacFullQA/source/apple/PDFno.xcodeproj \
  -scheme PDFnoMac -configuration Debug -destination 'platform=macOS' \
  -derivedDataPath .build/MacFullQA/DerivedData -jobs 1 \
  -disableAutomaticPackageResolution -skipPackageUpdates build-for-testing \
  CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY=- DEVELOPMENT_TEAM= \
  CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO CODE_SIGN_ENTITLEMENTS=
python3 -B qa/mac-ui-regression/configure.py --qa .build/MacFullQA --scope gate17
python3 -B qa/mac-ui-regression/configure.py --qa .build/MacFullQA --scope remaining56
```

On the user's Mac, use the repository's heavy-check lock for compilation and
obtain the current desktop handoff before running GUI tests. The workflow runs
them on a dedicated GitHub Mac runner. The exact approved branch selects
`shared8` diagnosis or `mac73`; main and pull requests retain the original
production `full60` path. Eight diagnostic passes alone do not establish full
reader acceptance.

The Mac73 workflow first checks actual logical display and visible-frame sizes.
`CIReadableDisplay.swift --configure-ci` refuses execution outside the exact
approved push, repository and disposable GitHub `runner` account. It selects
only an already supported desktop mode, scoped to that VM's login session;
it never writes a permanent configuration. Do not run this configuration helper
on a user's Mac. If no suitable mode exists, the job reports an environment
block before GUI input. The guarded fixture app also records the actual window
and content geometry and requires the original size and a 24-point drag margin.
Wide tests remain 1280×800 and narrow tests remain 720×520.

The temporary `diagnostic6` execution scope reruns only the six actual c871185
failures, keeping their original assertions and limits. It records bounded
source AX attributes and one owned-window image once original text is present,
then exercises real selection within the original wait. It creates no selection
and changes no document. Its result is explicitly
diagnostic; neither the 17-method gate nor the remaining56 runs in this scope.
Restore execution scope `gate17` for full acceptance after diagnosis.

Run each generated xctestrun with parallel testing disabled and the original
180/240-second limits. Capture the actual `xcodebuild` exit code and pass it to
`verify-result.py` with `--qa`, `--scope`, `--result`, `--log` and `--exit-code`.
The workflow shows the complete commands. Verification requires every expected
distinct method to pass, zero skips and expected failures, and exit code zero.
It copies only log-recorded screenshots under the actual QA runner's reported,
allowlisted Documents root, with canonical paths and no symbolic links.

Keep both result bundles, logs, preparation records, binary hashes and original
failures. These offline functional results do not establish live AI quality,
production account state, release signing or distribution readiness.
