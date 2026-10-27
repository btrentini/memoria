# Privileged-operation threat model

The assets are other users' processes, unsaved work, authorisation material, process metadata and the integrity of displayed telemetry. Local applications, stale selections, reused PIDs, malformed messages and compromised optional telemetry code are relevant adversaries.

| Threat | Control in source | Remaining limitation or verification |
|---|---|---|
| PID reuse or exec | Re-query PID/start/boot and executable before signalling | Final PID-based TOCTOU window remains |
| Invalid scope | Reject PID ≤ 1, infrastructure, duplicates, expired confirmation and excessive counts | Same-path exec is not always observable |
| Force kill or tree expansion | Explicit review; no automatic escalation; fixed children-first list | New/reparented descendants need fresh review |
| False success | Observe exit separately from signal return | Inaccessible observation remains unverified |
| Untrusted XPC peer | Exact identifier/team on both ends; handshake before authorisation | Requires wrong-signer/team tests on a signed build |
| Authorisation reuse | Per-request check, transient external form, request age and replay cache | OS revocation and interruption need live testing |
| Arbitrary privileged execution | Only SIGTERM/SIGKILL; no command/path/environment/write API | Powermetrics is absent pending validation |
| Malformed messages | Bounded Data, typed decoding and validation | Real XPC fuzzing remains required |
| Worker crash or compromise | Unprivileged process, signature, minimal environment, bounded pipes/deadlines/restarts | Signature proves provenance, not private-API correctness |
| Hung worker or profiler child | Owned stdin, parent-death watcher, process-group teardown | Needs lifecycle and crash testing |
| False zero | Explicit absence, channel presence and finite/range checks | Independent reference measurement remains required |
| Metadata disclosure | No remote telemetry; aggregate-only recording/export; arguments on demand | Explicitly opened arguments may be sensitive |
| Incorrect protection label | Preserve errno; no inference from owner/signer/denial | Protection tests belong on an isolated system |
| Widget metadata disclosure | Aggregate-only, fixed-size cache in a matching Team App Group; deletion on opt-out; sandboxed extension without collectors | Other authorised App Group members can access it; old rendered content may persist until macOS refreshes |
| Malformed widget cache or link | Version/range/history/file-size checks; four navigation-only routes; no action URL parameters | Live signed-container and closed-window link checks remain pending |

Administrator operations are disabled by default. Registration, administrator approval and authorisation of an individual operation are separate stages. Unsigned builds cannot install a permissive helper.

The event abstraction can be tested without Endpoint Security. Entitlement, system-extension approval and TCC remain separate prerequisites. A hard helper lifetime bounds residency; it does not prove instantaneous revocation of an operation already in progress.

This implementation has not completed an independent security audit. Release requires signed-helper adversarial, installation/removal and cancellation tests.

Primary references: [Apple XPC peer-validation guidance](https://developer.apple.com/forums/thread/681053), [SMAppService](https://developer.apple.com/documentation/servicemanagement/smappservice), and [Endpoint Security entitlement](https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.developer.endpoint-security.client).
