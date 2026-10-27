# Source publication review

The v.10 publication contains source, original icon artwork, dependency notices and sanitised verification summaries. It excludes raw local evidence, process/socket captures, recorded PIDs, personal paths, credentials, signing identities and build products. The author uses a GitHub noreply email in the commit metadata.

Unused macmon CLI/server sources and their upstream process/file-list samples are omitted; the library files remain unchanged at the pinned commit. The modification record and SBOM disclose this source subset.

Gitleaks 8.30.1 was obtained from the upstream release and its archive matched the published SHA-256 checksum. The full default ruleset initially reported eight generic-key matches in Cargo checksum manifests. All were integrity hashes. The checked-in configuration permits only 64-character lowercase hexadecimal values in those specific checksum manifests; it does not exclude vendor source or other rules globally. `Scripts/verify-vendor.py` independently verifies all 1,007 retained vendored file digests. No unresolved secret-scanner findings remained.

`Scripts/check-publication.py` inspects the exact staged blobs for prohibited artefacts, personal filesystem paths, process-identity captures in published evidence and unexpected executable binaries. Generated PNG metadata was checked for identifying EXIF fields; the observed EXIF entries describe image format and resolution. Original image-generation provenance remains with the source artwork. Only intentional artwork and verified dependency tables are included as binary data.

The source review covered the helper's exact signer/team requirements, per-request authorisation and replay/age limits, fixed signal operations, target-identity checks, default-disabled experimental features, worker launch path/signature checks, bounded subprocesses, aggregate widget sharing and runtime network call sites. No unsigned-helper fallback or arbitrary privileged command interface is exposed. This is a scoped publication review, not an independent penetration test or a guarantee that the application has no vulnerabilities. Signed helper and live process-action acceptance remain explicit release gates.

Reproduce the publication checks from a staged checkout:

```sh
python3 Scripts/check-publication.py
python3 Scripts/verify-vendor.py
gitleaks git . --staged --config .gitleaks.toml --redact
```

Gitleaks is an audit tool, not an application dependency; the scripts do not download or install it. For a committed checkout, omit `--staged` to scan history. Raw scanner output and build logs should remain local. Do not attach live process lists, arguments, authorisation forms or credentials to public issues.
