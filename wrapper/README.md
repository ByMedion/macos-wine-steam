# steamwebhelper CEF wrapper

Works around Steam's client UI rendering as a **solid black window** under Wine
on Apple Silicon.

## The bug

Steam's UI is Chromium (CEF). Under Wine on Apple Silicon:

1. CEF's ANGLE backend tries D3D11 and fails:
   `Renderer11: Error querying driver version from DXGI Adapter`.
2. ANGLE falls back to GLES 2.0, but CEF wants 3.0:
   `eglCreateContext: Requested GLES version (3.0) is greater than max supported (2, 0)`.
3. CEF disables the GPU and software-renders, and its transparent-background
   window ends up painted black.

Additionally, CEF's out-of-process `NetworkService` talks TLS through Wine's
winsock and produces a handshake-failure cascade, which breaks sign-in.

This is **not** caused by DXMT -- the same ANGLE failure occurs with DXMT
entirely unloaded, because Wine's builtin `d3d11`/`dxgi` hit it too.

## Why a wrapper

Steam's own `-cef-*` flags do not fix it. Of the flags that matter, only
`-cef-disable-gpu-compositing` is honoured, and it is not sufficient. The flags
have to be applied to `steamwebhelper.exe` itself, so the wrapper takes that
binary's place:

- Valve's binary is renamed to `steamwebhelper_real.exe`
- the wrapper is installed as `steamwebhelper.exe`
- it injects `--disable-gpu --single-process` and delegates

`--single-process` matters for two independent reasons: it stops the renderer
opening its own D3D11 swapchain (which paints black), and it collapses the
`NetworkService` into the browser process, avoiding the winsock TLS cascade.

## `-noverifyfiles` is required too

The wrapper alone is not enough. Steam runs an executable-checksum pass during
boot that **silently restores Valve's original binary over the wrapper**, so the
black window returns on the very next launch. `run.command` therefore launches
Steam with `-noverifyfiles`, and re-deploys the wrapper on every launch.

If you are debugging this, compare file sizes -- the wrapper is ~150 KB, Valve's
binary is ~7.5 MB:

```bash
find "$WINEPREFIX/drive_c/Program Files (x86)/Steam/bin/cef" \
  -name "steamwebhelper*.exe" -exec ls -l {} \;
```

## Building

Requires Homebrew's `mingw-w64`. `run.command` invokes this automatically, but
you can run it by hand:

```bash
./wrapper/install-wrapper.sh              # build if needed, then deploy
./wrapper/install-wrapper.sh --build-only # build only
./wrapper/install-wrapper.sh --deploy-only # deploy cached binary
```

The built binary is cached at `~/.merlot/cef-wrapper/steamwebhelper.exe` so that
installed `Merlot Apps` bundles can redeploy it without needing the toolchain.

Set `MERLOT_CEF_WRAPPER=0` to disable the wrapper entirely (expect a black UI).

## Credit

`src/steamwebhelper-wrapper.c` is vendored from
[notpop/steam-on-m1-wine](https://github.com/notpop/steam-on-m1-wine) and is MIT
licensed -- see `LICENSE.notpop`. That project diagnosed this bug and the
`-noverifyfiles` interaction; this directory packages the same fix for this
repository.
