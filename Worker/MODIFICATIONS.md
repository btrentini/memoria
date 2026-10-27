# Vendored macmon modification record

Upstream: https://github.com/vladkens/macmon/tree/39e98aa73e49256e6281b2a228f6ef3499ae3209

The retained library files under vendor/macmon/src are unchanged from that commit. SOURCE_SHA256.json records their SHA-256 digests. The upstream MIT licence is retained. Cargo.upstream.toml retains the original manifest.

The replacement Cargo.toml disables automatic binary discovery and declares only the library's four direct dependencies, pinned to the upstream locked versions. Default/application features are empty and no application target is built. This excludes CLI, server and updater dependency paths from the shipped worker. The unused src/app directory is omitted from the published source, including its HTTP server, updater/CLI code and process/file-list fixtures with sample personal paths. These modules were never linked by the worker. Library behaviour is unchanged.

Registry sources are extracted unchanged from archives whose SHA-256 digests match the upstream Cargo.lock. Cargo checksum manifests are generated from the extracted files. Licence files are retained. Cargo's directory source replacement enables locked offline builds.

Memoria's protocol, supervision, capability checks and conversion code are original code in src/main.rs, outside the vendored source.
