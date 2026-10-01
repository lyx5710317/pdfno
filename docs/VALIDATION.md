# Validation evidence · 2026-10-01

Scope: source skeleton and self-authored demo text, not a licensed reading engine or production AI.

| Check | Actual outcome | Evidence / scope |
| --- | --- | --- |
| Official `npm ci` | PASSED | Clean installation of locked dependencies with Node 24.21.0 / npm 10.8.2 |
| `npm run lint` | PASSED | Final source and tests; initial error handling / formatter conflict corrected |
| `npm run typecheck` (also inside build) | PASSED | Strict TypeScript 6.0.3 |
| `npm test` | PASSED | 3 files, 11 tests: ruby/Unicode offsets, duplicate quotes, immutable snapshots, invalid spans, cancellation/partial/failure, note revision/backup/restart, corruption protection, origin/traversal/endpoint checks |
| `npm run build` | PASSED | Vite 8.3.2 production renderer; final build has no Node file-system imports |
| `npm run native:build -- -quiet` | PASSED | Xcode 27.0 / Swift 6.4, generic macOS destination, unsigned universal arm64+x86_64 CLI |
| `npm run native:check` | PASSED | Exact capability JSON; unsupported operation rejects with exit 64 |
| `npm run test:e2e` | PASSED | 1 actual Electron 44.5.1 test, 5 seconds; fixture selection, separate mode drafts, A/B task isolation, cancel/rate-limit, local note save/restart, Swift query and 760px narrow view |
| `npm run notices` | PASSED | 211 locked dependency entries, all declared licenses recorded |
| Official npm audit | PASSED | Clean install reports 0 known vulnerabilities; this is not a general security guarantee |
| Complete AGPL comparison | PASSED | Git blob SHA matches pinned upstream `f23ede7e4a57a42d4afea20c01b244991fa344a5` |
| Staged diff / source scan | PASSED before publication | Text-file inventory, known secret/personal-path patterns, excluded assets, official lock URL/integrity check; see publication commit |

## Corrections during validation

The first dependency attempt selected TypeScript 7, which did not satisfy lint tooling's peer range; 6.0.3 resolves the constraint. The host's default mirror does not implement security audits, so final resolution/installation and audit used the official registry and a clean lock. A browser import of the combined file repository initially generated a warning; pure schema validation now lives in `shared`.

Initial desktop launches timed out before any UI assertion. Moving ESM ready-dependent initialisation into `app.whenReady().then(...)` fixed the lifecycle; subsequent full desktop tests passed, including restart. No renderer isolation or sandbox was disabled to make the test pass. A non-fatal macOS sandbox-extension diagnostic appeared in debug startup logs; the tested renderer still uses `sandbox:true`, `contextIsolation:true` and `nodeIntegration:false`. Playwright also reports a non-fatal colour-environment warning.

## NOT RUN / retained limitations

- Full upstream Koodo build and all genuine PDF/EPUB/comic import/render/annotation tests: engine rights/source unresolved; no engine in this skeleton.
- Genuine PDF coordinate round-trips, EPUB CFI/reflow, scans/OCR, vertical writing and complex ruby or multi-block selection; demo supports a single block only.
- Real BYOK connectivity, paid model responses and semantic language quality; no API keys collected and no model requests made.
- Bookno receiver/API/cover transport, iCloud multi-device conflict/recovery, conversion quality; interfaces/statuses only.
- Intel hardware runtime, signed DMG, Gatekeeper/notarisation, clean application install/upgrade, auto-update and native entitlements.
- Full VoiceOver, keyboard-only workflow, pointer selection across complex markup, system split view/fullscreen/multi-window, retained source after app restart, persistent layout/preferences.
- Manual web-only development-mode smoke test; the verified desktop path is `npm run build` then `npm start`.
- Cloud CI results are recorded below; they are independent of local verification.

The local screenshot under ignored `test-results/desktop-workspace.png` contains only self-authored fixtures and isolated test notes. It was visually inspected for layout; it is not a private desktop screenshot and is not published as a production reader/AI result.

## Cloud CI follow-up

Initial [run 36897686384](https://github.com/lyx5710317/pdfno/actions/runs/36897686384) on `b77d5c6` failed only in the native job's desktop test. Linux source checks, macOS Xcode build, native protocol and renderer build all passed. The desktop log shows the initial Electron binary download starting inside the test and exhausting its 30-second limit before UI assertions.

The corrective change adds `npm run electron:install` as a separate native CI step with a five-minute installation bound, before desktop tests. The test timeout and assertions stay unchanged. No application functionality, renderer security settings, dependencies or account permissions change. Final cloud status must be verified on the new commit.

Follow-up trace from [run 36899300704](https://github.com/lyx5710317/pdfno/actions/runs/36899300704) showed that launch and the home-page assertion passed; the remaining timeout occurred while clicking the first paragraph. A local 1024px reproduction confirmed the open responsive navigation overlay intercepted pointer events. The workspace now initially collapses navigation on narrow windows, collapses when crossing that breakpoint, and closes the temporary pane after navigation. The same desktop test explicitly exercises a 1024px initial view and retains its 760px check, without force clicks or weakened assertions. Source snapshots, drafts and tasks are preserved.
