# Changelog

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
