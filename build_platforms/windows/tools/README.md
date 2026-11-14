# Windows build tools

- `rcedit-x64.exe`: [electron/rcedit](https://github.com/electron/rcedit) v2.0.0
  (MIT, see `LICENSE.rcedit.txt`), from its GitHub release.
  SHA-256 `3e7801db1a5edbec91b49a24a094aad776cb4515488ea5a4ca2289c400eade2a`.
  `../build_windows.sh` runs it under Wine to give `Songo5.exe` Songo's icon
  and version info. It's only used at build time and isn't shipped.
