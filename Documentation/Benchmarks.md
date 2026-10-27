# Recorded checks and remaining budgets

These results come from this restricted ARM64 macOS session. The chip model is unverified. Concurrent compiler/test activity was present; these are functional checks, not an Instruments performance profile.

| Check | Recorded result | Scope |
|---|---|---|
| Filter and sort 5,000 synthetic process rows | Optimised library p95 6.75 ms; Debug 16.47 ms | 25 iterations; core function only, excluding UI dispatch, rendering and presentation |
| One-thread CPU fixture | 99.35% of one core | About 1.1 seconds; converted libproc time agrees with final getrusage within 0.2% |
| Two-thread CPU fixture | 197.39% of one core | About 1.1 seconds; agreement with final getrusage within 0.3% |
| Touched memory | About 32 MiB additional footprint | Disposable child; no assertion of exact system accounting equality |
| History retention | Eight hours of simulated samples bounded by count/time limits | No wall-clock soak or process-wide leak claim |
| Background work admission | Limit/cancellation test | One running native job; at most sixteen admitted per executor by default |

Warm Quick Task Manager presentation below 200 ms, full UI search response below 100 ms, monitoring CPU below 5%/2% of one core, baseline footprint below 250 MB, energy impact and an eight-hour soak remain open. Optional-worker cost must be measured separately on validated hardware.

The test logs are the authoritative values for the delivered run. Results vary with system load and build configuration.
