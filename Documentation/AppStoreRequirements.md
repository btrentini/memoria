# App Store preparation ledger

This follow-up implements the requested submission template. The user has no Apple Developer team yet and asked to leave submission details for later. The original direct edition remains separate. Evidence is summarised in [Validation.json](../AppStore/Validation.json); no successful upload, signed installation or complete acceptance is claimed.

| Requirement | Implementation/evidence | Status |
|---|---|---|
| Separate sandboxed application and widget targets | Shared MemoriaStore scheme; generated project; source graph checks | Implemented; SDK compilation verified |
| Public APIs, no privileged/process-control components | MemoriaStoreMetrics/Native; binary import and dependency checks | Verified statically; live sandbox visibility pending |
| CPU, memory, interface, battery and thermal monitoring | Store collectors and six native views | Implemented; local preview readings observed; workload acceptance pending |
| Retain direct edition | Original scheme and targets; 55 regression tests | Verified at module/test level |
| Prevent gaps/resets from fabricating rates | Five store metric tests | Verified |
| Local menu-bar monitor and opt-in aggregate widgets | StoreApp; shared widget model; separate route/group | Implemented; signed widget activation pending |
| Privacy manifests and in-app privacy explanation | Two privacy resources; PrivacyAudit.md | Implemented and structurally checked |
| Listing drafts and metadata limits | Metadata/en-GB; check-app-store.py | Verified against local length checks |
| Privacy/support webpage templates | Site/privacy.html and support.html | Implemented; hosting deferred |
| Future archive/export commands | app-store.py; no upload action; missing-team guard | Implemented; signed execution deferred |
| No credentials or captured process data in template | Secret/publication scans; source-only archive inventory | Verified for prepared snapshot |
| Real store screenshots | Preview-Overview.jpg; Screenshots/README.md | Local preview capture reviewed; final signed-build set deferred |
| Developer account, profiles, URLs and contact | Explicit null fields in Submission.json | Deferred by user |
| Xcode archive, signed installer and upload | Requires functioning archive tools and signing setup | Blocked externally |

The local background lifecycle and five additional policy tests are recorded in [BackgroundVerification.json](../Evidence/BackgroundVerification.json). Login registration is intentionally disabled in the temporary preview and remains pending a permanent installation.
