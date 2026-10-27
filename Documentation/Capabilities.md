# Capability matrix

| Capability | Source / tier | Current behaviour | Verification boundary |
|---|---|---|---|
| Host/per-core CPU and load | Mach and getloadavg / 1 | Interval deltas, unknown P/E mapping | Native enumeration and one/two-thread CPU-time comparison passed; no P/E mapping claim |
| Process identity/resources | libproc and boot query / 1 | Per-field errors; stale identity rejects action | Own-process inspection observed; boot identity denied in agent sandbox |
| Memory/swap/pressure | Mach, sysctl, Dispatch / 1 | Components, explicit pressure unknown before events | 32 GiB observed; touched-page footprint check passed; live pressure notification checks pending |
| Volume capacity | Foundation / 1 | Per volume; no shared-APFS summation | No volumes exposed in this session; APFS/external-drive acceptance pending |
| Process I/O | libproc / 1 | Labelled process accounting | Does not establish device traffic |
| Storage-driver activity | Documented IOKit statistics / 1 | Per-service counters and reset-aware rates | Physical-device workload/reference comparison pending |
| Interface traffic | getifaddrs / 1 | Per interface, reset-aware; no duplicate aggregate | VPN/churn/throughput validation pending |
| Ports and connections | libproc, bounded lsof / 1 | Permission-limited scan; TCP/UDP/IPv4/IPv6 | Listener/replacement acceptance pending |
| Battery/thermal state | Public power APIs, ProcessInfo / 1 | Hardware absence remains unavailable | Sensor presence varies by machine |
| GPU/power/temperature/fans | Optional macmon worker / 2 | Disabled unless signed and explicitly enabled | Offline ARM64 build and explicit subscription-absence check passed; measurement/reference checks remain blocked |
| Administrator termination | SMAppService/XPC/Authorization / 3 | Disabled without configured signing team | Signed cross-user tests require credentials and isolated system |
| Privileged powermetrics | No adapter enabled / 3 | Unavailable | Schema, overhead and operation review required |
| Process lifecycle events | Reconciliation model; future ES provider / 4 | Polling works independently | Apple-approved entitlement/provisioning required |
| Per-process GPU/network attribution | No validated source | Unavailable | Separate feasibility investigation |
| Menu-bar monitor | Existing native aggregates / 1 | Configurable readings and chart popover | Compiles; live UI and window lifecycle unverified |
| Desktop/Notification Centre widgets | Aggregate App Group snapshot and WidgetKit / 1 | Small/medium, timestamped, missing/stale states | Cache policy tests pass; signed-container delivery and gallery acceptance remain gated |

Missing, denied, unsupported, stale, failed and disabled states exist separately in the metric model. Measured zero is a present numeric value with available status. A permission denial is not a SIP-protection determination. Neither root ownership nor an Apple signature establishes process protection.

The original requested M2 Pro identity was not independently verified. Twelve logical cores and 32 GiB are observed characteristics, not a model identification. macOS 26.7.1 / ARM64 is the inspected runtime; other Apple Silicon generations and OS releases remain unverified.
