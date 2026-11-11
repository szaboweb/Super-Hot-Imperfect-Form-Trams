# Distribution notes

- **Windows**: `flutter build windows --release` → zip `build/windows/x64/runner/Release`.
- **Steam Deck / Linux**: `flutter build linux --release` → zip `build/linux/x64/release/bundle`
  (runs natively on SteamOS; add as a non-Steam game or ship via Steam with a Linux depot).
  Gamepad input: Steam Input maps controller to keyboard by default; native gamepad support is planned.
- **itch.io**: upload zips with `butler push <dir> szaboweb/super-hot-imperfect-form-trams:windows`
  (use `:linux` for the Linux build). `distribution/itch/` is for `.itch.toml` manifests and page assets.
- **Steam**: `distribution/steam/` is for SteamPipe build scripts (`app_build.vdf`, depot scripts) and store art.
