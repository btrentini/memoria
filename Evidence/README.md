# Published verification summaries

This directory contains sanitised summaries and dependency-advisory requests/responses. Raw compiler logs, crash reports, live process/socket captures, local filesystem paths, machine identifiers and runtime exports are not published. Numeric test inputs in `Tests/` are synthetic fixtures; process identifiers used by the application are collected at runtime.

[Verification](../Documentation/Verification.md) records the tested configurations, outcomes and limits. [Publication checks](PublicationChecks.json) record the checks repeated for this source publication. The Git commit identifies the source; summaries of earlier runs do not claim that the graphical application launched successfully.

- `Environment.json`: OS/compiler versions and availability, without machine or workspace identifiers.
- `VerificationSummary.json`: earlier compiler, unit, native-workload and performance results, with their scope.
- `RequirementVerification.json`: evidence overrides consumed by the requirements-ledger generator.
- `RankingVerification.json`, `SimplifiedViewVerification.json`, `WidgetVerification.json`: implementation and verification boundaries for interface additions.
- `IconVerification.json`, `IconImageMetadata.json`: icon export checks and unresolved system-rendering acceptance.
- `osv-query.json`, `osv-response.json`: the exact fourteen registry versions queried and the database response on the audit date. These contain package metadata, not application telemetry.

References to this file in the ledger indicate that a local log was reviewed and withheld. They are summaries, not publicly reproducible raw traces. Run the commands in [Build.md](../Documentation/Build.md) to collect evidence locally; review any output before sharing it.
