# Changelog

## [0.8.1](https://github.com/musher-dev/engineering-conventions/compare/v0.8.0...v0.8.1) (2026-10-03)


### Bug Fixes

* **conventions:** judge an IMAGE-09 glob by the Dockerfiles it misses ([#88](https://github.com/musher-dev/engineering-conventions/issues/88)) ([ad4965c](https://github.com/musher-dev/engineering-conventions/commit/ad4965c9376667b4b49081cde9636632b6e180f4))

## [0.8.0](https://github.com/musher-dev/engineering-conventions/compare/v0.7.1...v0.8.0) (2026-10-03)


### ⚠ BREAKING CHANGES

* **conventions:** make AGENTS.md the memory and generate the .env

### Features

* **conventions:** keep images in docker/ and lint them with hadolint ([6289e62](https://github.com/musher-dev/engineering-conventions/commit/6289e62abd8869db8913cc0ca0fc31fa7d6f9de1))
* **conventions:** make AGENTS.md the memory and generate the .env ([6289e62](https://github.com/musher-dev/engineering-conventions/commit/6289e62abd8869db8913cc0ca0fc31fa7d6f9de1))
* **conventions:** protect the default branch and update every pin ([6289e62](https://github.com/musher-dev/engineering-conventions/commit/6289e62abd8869db8913cc0ca0fc31fa7d6f9de1))

## [0.7.1](https://github.com/musher-dev/engineering-conventions/compare/v0.7.0...v0.7.1) (2026-10-01)


### Features

* **conventions:** add conventions for agent skills, commits and copy ([387ce19](https://github.com/musher-dev/engineering-conventions/commit/387ce194b54f01fca32259934354ede15ff6d7e8))
* **conventions:** add interface formats and fetched dependencies ([387ce19](https://github.com/musher-dev/engineering-conventions/commit/387ce194b54f01fca32259934354ede15ff6d7e8))
* **conventions:** check devcontainer.json schema and variables ([387ce19](https://github.com/musher-dev/engineering-conventions/commit/387ce194b54f01fca32259934354ede15ff6d7e8))
* **conventions:** check Taskfile fragments, silent and prefixed tasks ([387ce19](https://github.com/musher-dev/engineering-conventions/commit/387ce194b54f01fca32259934354ede15ff6d7e8))
* **conventions:** check that copy, OpenAPI and community tooling is wired ([387ce19](https://github.com/musher-dev/engineering-conventions/commit/387ce194b54f01fca32259934354ede15ff6d7e8))
* **conventions:** declare runtime requirements with version ranges ([387ce19](https://github.com/musher-dev/engineering-conventions/commit/387ce194b54f01fca32259934354ede15ff6d7e8))
* **conventions:** derive the env contract and .env.example from the schema ([387ce19](https://github.com/musher-dev/engineering-conventions/commit/387ce194b54f01fca32259934354ede15ff6d7e8))
* **conventions:** name bindings after the program that reads them ([387ce19](https://github.com/musher-dev/engineering-conventions/commit/387ce194b54f01fca32259934354ede15ff6d7e8))
* **conventions:** require a GHCR image to name its source repository ([387ce19](https://github.com/musher-dev/engineering-conventions/commit/387ce194b54f01fca32259934354ede15ff6d7e8))
* **conventions:** skip vendored env schemas and register five runtime capabilities ([387ce19](https://github.com/musher-dev/engineering-conventions/commit/387ce194b54f01fca32259934354ede15ff6d7e8))


### Bug Fixes

* **conventions:** name the breaking mark as the signal for a gated break ([387ce19](https://github.com/musher-dev/engineering-conventions/commit/387ce194b54f01fca32259934354ede15ff6d7e8))

## [0.7.0](https://github.com/musher-dev/engineering-conventions/compare/v0.6.4...v0.7.0) (2026-09-30)


### ⚠ BREAKING CHANGES

* **conventions:** declare interfaces and vendored dependencies, and what each binding reaches

### Features

* **conventions:** add the OpenTofu state key convention (TOFU-01, EC-0029) ([21d71d8](https://github.com/musher-dev/engineering-conventions/commit/21d71d8ffe7e18eccaa8a9412f634f96dbb83175))
* **conventions:** declare interfaces and vendored dependencies, and what each binding reaches ([cc6d5a4](https://github.com/musher-dev/engineering-conventions/commit/cc6d5a4d90710abd67f57e93747f31418f1a5df9))
* **conventions:** forbid fixed dev container names and foreign home volumes (DEVC-14, DEVC-15) ([cc6d5a4](https://github.com/musher-dev/engineering-conventions/commit/cc6d5a4d90710abd67f57e93747f31418f1a5df9))
* **terminology:** add the notify workflow and sync action tokens, and keep action synonyms as data ([21d71d8](https://github.com/musher-dev/engineering-conventions/commit/21d71d8ffe7e18eccaa8a9412f634f96dbb83175))


### Bug Fixes

* **checks:** accept an OpenTofu root as REPO-17's build manifest ([cc6d5a4](https://github.com/musher-dev/engineering-conventions/commit/cc6d5a4d90710abd67f57e93747f31418f1a5df9))
* **checks:** resolve Taskfile paths under dir: and map-form includes as go-task does (TASK-08) ([21d71d8](https://github.com/musher-dev/engineering-conventions/commit/21d71d8ffe7e18eccaa8a9412f634f96dbb83175))
* **checks:** tell URL-shaped identifiers to leave format unset (ENVS-12) ([21d71d8](https://github.com/musher-dev/engineering-conventions/commit/21d71d8ffe7e18eccaa8a9412f634f96dbb83175))

## [0.6.4](https://github.com/musher-dev/engineering-conventions/compare/v0.6.3...v0.6.4) (2026-09-30)


### Features

* **conventions:** attest release assets only where attestations exist (REL-18) ([#62](https://github.com/musher-dev/engineering-conventions/issues/62)) ([068c1f6](https://github.com/musher-dev/engineering-conventions/commit/068c1f626bbd1c5c6fd8d0e267d238a51a65af49)), closes [#61](https://github.com/musher-dev/engineering-conventions/issues/61)

## [0.6.3](https://github.com/musher-dev/engineering-conventions/compare/v0.6.2...v0.6.3) (2026-09-29)


### Features

* **conventions:** add dev container conventions (DEVC) and decision 0020 ([#59](https://github.com/musher-dev/engineering-conventions/issues/59)) ([99907a2](https://github.com/musher-dev/engineering-conventions/commit/99907a29d72c53c8051da4a38287b9d3a5d9be76))

## [0.6.2](https://github.com/musher-dev/engineering-conventions/compare/v0.6.1...v0.6.2) (2026-09-29)


### Features

* **conventions:** add the release conventions (EC-0024 to EC-0026) ([d94523b](https://github.com/musher-dev/engineering-conventions/commit/d94523be9e4cf2e7b7ce2845449791c645a8c3d3))
* **conventions:** add the site and machine image output kinds ([d94523b](https://github.com/musher-dev/engineering-conventions/commit/d94523be9e4cf2e7b7ce2845449791c645a8c3d3))
* **schemas:** let a repository adopt the conventions one family at a time ([d94523b](https://github.com/musher-dev/engineering-conventions/commit/d94523be9e4cf2e7b7ce2845449791c645a8c3d3))


### Bug Fixes

* **checks:** leave a malformed repository name to REPO-08 ([#46](https://github.com/musher-dev/engineering-conventions/issues/46)) ([43b94d1](https://github.com/musher-dev/engineering-conventions/commit/43b94d12449c927726db069538c88a58eddc0e7d))
* **checks:** stop reporting advice text, config-named files and build output ([#44](https://github.com/musher-dev/engineering-conventions/issues/44)) ([293d25c](https://github.com/musher-dev/engineering-conventions/commit/293d25ccf6e89a30abd5588c5a6295367eb4cd5c))
* **rulesets:** make the musher-release App the release-tag bypass actor ([f266320](https://github.com/musher-dev/engineering-conventions/commit/f2663204a68f6d4d0d1348f7c3c6e00ea087239a))

## [0.6.1](https://github.com/musher-dev/engineering-conventions/compare/v0.6.0...v0.6.1) (2026-09-28)


### Bug Fixes

* **checks:** stop parsing Dockerfile ignore files and reading handles as imports ([#38](https://github.com/musher-dev/engineering-conventions/issues/38)) ([bff02ec](https://github.com/musher-dev/engineering-conventions/commit/bff02ecebcdafe15cfc81a152e4d69efa1743fde))

## [0.6.0](https://github.com/musher-dev/engineering-conventions/compare/v0.5.0...v0.6.0) (2026-09-28)


### Features

* **cli:** read JSONC, any Dockerfile and agent-context text into the check ([#27](https://github.com/musher-dev/engineering-conventions/issues/27)) ([0700ea0](https://github.com/musher-dev/engineering-conventions/commit/0700ea0d53ab0aab36e19922c9ba5b72e6a9c607))
* **conventions:** adopt general governance from the platform and development-container ([#37](https://github.com/musher-dev/engineering-conventions/issues/37)) ([baa1dfa](https://github.com/musher-dev/engineering-conventions/commit/baa1dfa2fbe2248e02d77c6e11e3b52540f4554c))


### Bug Fixes

* **conventions:** let a release workflow publish what it releases ([#25](https://github.com/musher-dev/engineering-conventions/issues/25)) ([75fae34](https://github.com/musher-dev/engineering-conventions/commit/75fae349e320e55261df8a75a2dafc3c4fea8c68))

## [0.5.0](https://github.com/musher-dev/engineering-conventions/compare/v0.4.0...v0.5.0) (2026-09-27)


### ⚠ BREAKING CHANGES

* **conventions:** a YAML declaration is no longer read. A repository that has .repo/conventions.yaml or .repo/outputs.yaml renames it to .toml, rewrites it in TOML, and quotes every date: an unquoted `expires = 2026-12-01` is a TOML date, which conftest renders as 2026-12-01T00:00:00Z, and ADOPT-02 now reports it with a message that asks for the quotes. The ADOPT-05 message says "set expires to" instead of the YAML "set expires: to". OUT-01's title names .repo/outputs.toml.

### Features

* **conventions:** name repositories, declare their identity, and move .repo/ to TOML ([#23](https://github.com/musher-dev/engineering-conventions/issues/23)) ([de17c9b](https://github.com/musher-dev/engineering-conventions/commit/de17c9ba9b13bd858211906884a45b56cdac713c))

## [0.4.0](https://github.com/musher-dev/engineering-conventions/compare/v0.3.0...v0.4.0) (2026-09-24)


### ⚠ BREAKING CHANGES

* **cli:** --output json no longer prints conftest's result shape; read the findings from the top-level array instead of .[].warnings[].metadata.

### Features

* **cli:** print a readable report by default, and our own JSON ([#20](https://github.com/musher-dev/engineering-conventions/issues/20)) ([330567d](https://github.com/musher-dev/engineering-conventions/commit/330567db4be4e522288a2ebcc406ff1e8e842ce3))


### Bug Fixes

* **checks:** give GHA-38 advice for secrets that GitHub can follow ([#19](https://github.com/musher-dev/engineering-conventions/issues/19)) ([7c41702](https://github.com/musher-dev/engineering-conventions/commit/7c41702f66a6e1155198891b8be39a4391d7a21b))

## [0.3.0](https://github.com/musher-dev/engineering-conventions/compare/v0.2.0...v0.3.0) (2026-09-24)


### Features

* **conventions:** declare repository outputs, and separate definitions from checks ([#16](https://github.com/musher-dev/engineering-conventions/issues/16)) ([ad376ad](https://github.com/musher-dev/engineering-conventions/commit/ad376ad2c580921a5e5f60d60094a52874c8fd3d))

## [0.2.0](https://github.com/musher-dev/engineering-conventions/compare/v0.1.0...v0.2.0) (2026-09-24)


### ⚠ BREAKING CHANGES

* **repo:** a conventions declaration that sets `area:` no longer validates (ADOPT-02). Remove the field; it had no effect.

### Features

* **repo:** clean starting point, and consume a release as one mise pin ([#14](https://github.com/musher-dev/engineering-conventions/issues/14)) ([769305c](https://github.com/musher-dev/engineering-conventions/commit/769305c7d3bc60cb1ddec2b54b3492f158906f8b))

## 0.1.0 (2026-09-23)


### Features

* **repo:** scaffold engineering-conventions ([60dd437](https://github.com/musher-dev/engineering-conventions/commit/60dd4371bcb0e9e03696aaa5a32f0791a2186d20))
