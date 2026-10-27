# Privacy manifest mapping

The App Store targets include separate `PrivacyInfo.xcprivacy` resources. Both declare no tracking, no tracking domains and no collected-data categories. They contain no third-party SDKs.

| Target | Required-reason category | Reason | Actual use |
|---|---|---|---|
| App | System boot time | 35F9.1 | `systemUptime` measures intervals between samples and bounds widget publication; no boot timestamp or device identifier is retained or transmitted |
| App | User defaults | CA92.1 | Store display preferences in this app's own defaults domain |
| App and widget | File timestamps/metadata | C617.1 | Inspect size/type of the fixed aggregate cache file inside the app's shared container before bounded reading |

These reasons follow [Apple's required-reason API definitions](https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitype). The cache contains only aggregate CPU/memory readings, a capture time, pressure state and up to thirty recent CPU points. It contains no PIDs, process names, arguments, executable paths, network addresses, authorisation material or stable device identifier.

App Sandbox entitlements allow only the sandbox and the configured App Group. No network client/server, Apple Events, accessibility, temporary exceptions or user-file access is requested. All chart history stays in memory; widget sharing is off by default and the app provides an opt-out deletion action.

Review the final compiled binaries and all future SDK additions before submission. App Store Connect's privacy label, the public policy and the manifests must remain consistent. [Apple's privacy-label guidance](https://developer.apple.com/app-store/app-privacy-details/)
