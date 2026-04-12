# Bundled mihomo (Clash.Meta) kernels

These directories hold the native mihomo binaries that get packaged into the
Flutter asset bundle (desktop) or the APK's `jniLibs/` (Android). They are
**not committed to git** — run the download script before building:

```bash
./scripts/download-kernels.sh
```

That populates:

- `assets/bin/windows/mihomo.exe` — Windows x86_64
- `assets/bin/macos/mihomo-amd64` — macOS Intel
- `assets/bin/macos/mihomo-arm64` — macOS Apple Silicon
- `android/app/src/main/jniLibs/<abi>/libmihomo.so` — Android (arm64 / armv7 / x86_64)

Kernel version is pinned in the script via `MIHOMO_VERSION` (default is the
latest stable release at the time of writing). Override with e.g.:

```bash
MIHOMO_VERSION=v1.20.0 ./scripts/download-kernels.sh
```

## How each platform finds the binary at runtime

- **Windows / macOS**: `MihomoProcessManager.ensureBinary()` reads the
  appropriate asset out of the Flutter asset bundle on first launch, writes it
  to `getApplicationSupportDirectory()/mihomo/`, `chmod +x`'s it, and spawns
  it with `-d <workdir>`.
- **Android**: the kernel is shipped under `jniLibs/<abi>/libmihomo.so` with
  `packaging { jniLibs { useLegacyPackaging = true } }` so Android extracts
  it into `applicationInfo.nativeLibraryDir` where files are executable. The
  `MihomoVpnService` spawns it from there after establishing the TUN fd and
  injecting `tun.file-descriptor` into the generated `config.yaml`.

Linux, iOS and Web are intentionally **not** built — the service layer emits
a "当前平台暂不支持 VPN 连接" error state on those platforms.
