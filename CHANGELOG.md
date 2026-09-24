# Changelog

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
