# Changelog

All notable changes to this project will be documented in this file. See [Keep a
CHANGELOG](http://keepachangelog.com/) for how to update this file. This project
adheres to [Semantic Versioning](http://semver.org/).

## 0.1.0 (2026-09-22)


### Features

* add generate/1 and fix canonicalisation to match HMRC ([41f244a](https://github.com/sgerrand/ex_irmark/commit/41f244a44da7a8fa6035973983d407259decef3f))
* add generate/1 to calculate the IRmark ([e4b0a51](https://github.com/sgerrand/ex_irmark/commit/e4b0a51b90a5c52d16adf633a457441c868828dd))
* add insert/2 to put an IRmark into IRheader ([6a1417f](https://github.com/sgerrand/ex_irmark/commit/6a1417fe595b4d6b5e739dce33011f081feffedc))
* add verify/1 and insert/2, fix non-ASCII parsing ([f379ccd](https://github.com/sgerrand/ex_irmark/commit/f379ccd430e9ca8c0a5037e3561c1800476e88e4))
* add verify/1 to check an existing IRmark ([e61444a](https://github.com/sgerrand/ex_irmark/commit/e61444a64e1b525d157e77dbd4658d9b54e38c28))
* **encode:** add encode32/1 for display ([2d8ae03](https://github.com/sgerrand/ex_irmark/commit/2d8ae034c8202f8ad40530d8b0452d16ab594793))
* **encode:** add encode32/1 for display ([a95908f](https://github.com/sgerrand/ex_irmark/commit/a95908f5f966f79ef25b7596de9d26b1bc842826))


### Bug Fixes

* **c14n:** ignore a leading byte order mark ([4e885a2](https://github.com/sgerrand/ex_irmark/commit/4e885a26af713542db00504cd92c7f9f5a4eb8a4))
* **c14n:** keep tabs in text as literal tabs ([1e0f834](https://github.com/sgerrand/ex_irmark/commit/1e0f83449e2da732a112c2c0997f3ff93a2aa079))
* **c14n:** keep whitespace between elements ([3128e59](https://github.com/sgerrand/ex_irmark/commit/3128e5991aafe1c0e66e0a9e7b3c710205aba1a8))
* **c14n:** leave out comments ([60e4164](https://github.com/sgerrand/ex_irmark/commit/60e4164f536b8bb83f5c716b22515c56fc1318e0))
* **c14n:** parse XML as UTF-8 bytes ([5bfdba0](https://github.com/sgerrand/ex_irmark/commit/5bfdba012f27ae0a3e5719c42ae6382e76dbc6c5))
* **c14n:** return error tuples for invalid XML ([8eccc64](https://github.com/sgerrand/ex_irmark/commit/8eccc64df75e4546c4cafbd151b2c6c3278bcdc0))
* **digest:** correct digest typespec to 160 bits ([996b391](https://github.com/sgerrand/ex_irmark/commit/996b39103fcbd64a6965747b87278aed9934a830))
* **encode:** stop truncating base64 output ([b9c8b61](https://github.com/sgerrand/ex_irmark/commit/b9c8b61c73eaf9051d98cc1a12e30e7c6182833b))
* stop truncating encode output and return c14n errors ([ea75329](https://github.com/sgerrand/ex_irmark/commit/ea75329cd8d8d1de8092b70950fe226e49cc27c6))

## [Unreleased]

Nothing released yet. release-please adds each release above this section,
because it needs a version heading to insert before. Delete this section once
the first release lands.
