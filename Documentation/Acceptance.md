# Acceptance and performance evidence

Run each scenario against the exact built configuration and record machine, source revision, sampling interval, timestamps and outcome. Tests that require personal applications, another account, protection boundaries or signing must remain separate from disposable-process tests.

| Scenario | Supplied mechanism | Required remaining evidence |
|---|---|---|
| Slack | Application grouping and normal/signal actions | Controlled grouping/resource comparison and user-approved quit |
| CPU load | Native and Swift fixtures, accounting tests | One/two-thread native response checked against getrusage; GUI response still pending |
| Memory load | Touched-page fixture | 32 MiB footprint change verified; GUI/system-accounting comparison pending |
| Local server | IPv4/IPv6/UDP fixtures, native scan, Free Port | Listener ownership and post-action rescan |
| Port/PID reuse | Identity tests, replacement-aware Free Port | Disposable replacement race |
| Other user | Signed helper | Dedicated account denial/authorised-success checks |
| Restricted process | Errno policy tests | Read-only everyday inspection; real signalling only isolated |
| GPU load | Metal fixture and optional worker | Matched-definition independent reference |
| Missing sensors | Worker decoder/optional UI | Crash, timeout, invalid-channel and absence runs |
| Helper security | Replay/size/version/signing policy | Wrong-signer/team, revoked auth, malformed XPC and uninstall |
| Efficiency | 5,000-row benchmark and bounded-history test | Instruments and actual eight-hour soak |
| Sleep/resume | Pause/baseline clearing/gap logic | Real sleep and wake, no fabricated spikes |
| Menu bar and widgets | Configurable status item, small/medium WidgetKit extension, bounded aggregate cache tests | Live appearance, signed gallery/container delivery, closed-window links, stale/sleep state and opt-out; see [widget checks](Widgets.md) |

The recorded core filter/sort test excludes UI dispatch and rendering. These application-level targets remain unverified budgets: warm Quick Task Manager p95 below 200 ms; 5,000-row filtering p95 below 100 ms; average monitoring CPU below 5% of one core visible and 2% in background on M2 Pro; baseline footprint below 250 MB; no unbounded growth over eight hours. Worker cost must be measured separately.

The simulated eight-hour history test verifies the container's size and retention arithmetic only. It does not test descriptor, task, process or memory growth in the running application. Native table reuse, bounded streams and queues support the design but do not replace profiling.

The agent sandbox denies boot-session UUID and boot-time queries. When both fail, the application intentionally refuses to construct verifiable termination targets. This is an execution-environment limitation, not evidence that ordinary macOS application processes lack those APIs.

## Process ranking follow-up

Every destination must show a numbered process list with independent sorting and filtering. Verify CPU defaults to CPU usage, Memory to footprint, Applications to application-associated processes by footprint, and Storage to combined read/write rates. Verify header sorting and the ranking picker stay in sync; unavailable readings stay last in either direction; zeros remain distinct from missing readings.

Check text, state, ownership, minimum CPU, minimum footprint and selected-metric availability filters together. Switch tabs and open the Quick Task Manager: each list must retain its own settings. Search text is retained only for the session; controls survive relaunch. Select a row to inspect it and review existing process actions. Resize the dashboard/table divider and test horizontal scrolling and keyboard access. GPU, Network and Power must explain unavailable attribution; History must label the list as current, not historical. The extended UI smoke visits all twelve destinations, but GUI execution remains blocked in this session.

## Simplified view follow-up

Switch the toolbar to Simple in each of the twelve tabs. Confirm that relevant charts and at most ten measured processes replace the detailed table and inspector. Change the summary ranking between CPU, footprint, resident memory, threads and I/O; verify highest values appear first, ties remain stable and missing readings never become zeros. Measured zero remains valid. Summary ranking uses all visible processes, except Applications, which uses application-associated processes. Full-view filters do not restrict the summary.

Switch back to Full and confirm its filters, columns and inspector preference are retained. Selecting a summary process should enter Full view and open that process in the inspector. Relaunch to verify the remembered view mode and summary ranking choices. Check the equivalent Settings → General option. The Quick Task Manager retains its detailed controls.

Network and Storage summaries select one interface or driver; their rates are not summed. GPU and power charts show current experimental measurements only where available. Ports charts use the latest explicit socket scan, with coverage visible; provider-status charts count capabilities. History charts use the selected time window while the top-ten list remains current. Check missing data, sleep, resize, keyboard and VoiceOver behaviour without assuming that compilation proves these UI outcomes.
