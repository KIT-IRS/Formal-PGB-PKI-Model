# Native Windows installation used for this repository

This document records the **tested native-Windows installation that successfully produced ProVerif 2.05 for this repository**.

It is not intended to replace the official installation documentation. Start with the official sources and use the workaround below only if the standard installation fails with the same `lablgtk` errors.

Official references:

- [ProVerif website](https://bblanche.gitlabpages.inria.fr/proverif/)
- [ProVerif 2.05 OPAM package](https://opam.ocaml.org/packages/proverif/)
- [ProVerif 2.05 manual](https://bblanche.gitlabpages.inria.fr/proverif/manual.pdf)
- [OCaml/OPAM installation documentation](https://ocaml.org/docs/installing-ocaml)
- [OCaml on Windows](https://ocaml.org/docs/ocaml-on-windows)
- [OPAM 2.1.0 release notes: integrated system/depext handling](https://opam.ocaml.org/blog/opam-2-1-0/)

The ProVerif 2.05 manual still shows the older `opam depext` workflow. OPAM has handled system dependencies directly since OPAM 2.1, so the tested setup below uses normal `opam install` commands instead.

## Tested environment

The final working environment was:

```text
Platform:        native Windows x86_64
OPAM:            2.5.2
OPAM Unix layer: internal OPAM-managed Cygwin
OCaml switch:    proverif
OCaml:           4.14.4
ProVerif:        2.05
lablgtk:         2.18.14, locally patched/pinned
```

A separate OCaml 5.5.0 `default` switch existed during the original setup, but it is **not required for ProVerif** and is therefore omitted from the reproduction procedure.

## 1. Install and initialize OPAM

Install OPAM using the official Windows instructions:

https://ocaml.org/docs/ocaml-on-windows

Initialize OPAM:

```powershell
opam init
```

When OPAM asks how to provide its Unix-like build environment, use the **OPAM-managed internal Cygwin installation**, which is the option recommended by the official Windows documentation.

The shell-integration choice is not essential to this repository. The tested setup used PowerShell and manually activated the required switch when necessary.

## 2. Create the dedicated ProVerif switch

Create a switch using OCaml 4.14.4:

```powershell
opam update
opam switch create proverif ocaml-base-compiler.4.14.4
```

Activate it in the current PowerShell session:

```powershell
(& opam env --switch=proverif --set-switch) -split '\r?\n' |
    ForEach-Object { Invoke-Expression $_ }
```

Verify:

```powershell
opam switch show
ocaml -version
```

Expected values are:

```text
proverif
The OCaml toplevel, version 4.14.4
```

## 3. Try the standard ProVerif installation first

Before applying any workaround, try the normal installation:

```powershell
opam install proverif.2.05
```

If this succeeds, no `lablgtk` workaround is necessary.

On the tested Windows environment, OPAM successfully installed the other dependencies but `lablgtk.2.18.14` failed. Two separate Windows-specific issues were observed:

1. GTK2 was installed, but the old `lablgtk` configure script did not use the required MinGW `pkgconf` personality.
2. `ml_gdkpixbuf.c` used `unsigned long` in two OCaml custom-serialization callback signatures, which did not match the `uintnat` types expected by the OCaml headers on this Win64 build.

The following steps reproduce the workaround that led to the successful installation.

## 4. Set the GTK2 pkg-config command

In the PowerShell session used for the installation:

```powershell
$env:PKG_CONFIG = 'pkgconf --personality=x86_64-w64-mingw32'
```

The GTK2 installation can be checked with:

```powershell
opam exec -- pkgconf --personality=x86_64-w64-mingw32 --modversion gtk+-2.0
```

On the tested setup this reported:

```text
2.24.33
```

This environment variable is session-local unless it is explicitly made persistent.

## 5. Create a local patched copy of `lablgtk` 2.18.14

Create a local source directory:

```powershell
$work = "$HOME\lablgtk-2.18.14-patched"

Remove-Item $work -Recurse -Force -ErrorAction SilentlyContinue
opam source lablgtk.2.18.14 --dir="$work"
```

Patch:

```text
src/ml_gdkpixbuf.c
```

The tested source contained:

```c
static void ml_GdkPixbuf_serialize (value v, unsigned long *wsize_32, unsigned long *wsize_64)
```

Change it to:

```c
static void ml_GdkPixbuf_serialize (value v, uintnat *wsize_32, uintnat *wsize_64)
```

The tested source also contained:

```c
static unsigned long ml_GdkPixbuf_deserialize (void *dst)
```

Change it to:

```c
static uintnat ml_GdkPixbuf_deserialize (void *dst)
```

The following PowerShell commands perform exactly those two replacements:

```powershell
$src = "$work\src\ml_gdkpixbuf.c"

$text = [System.IO.File]::ReadAllText($src)

$text = $text.Replace(
    'static void ml_GdkPixbuf_serialize (value v, unsigned long *wsize_32, unsigned long *wsize_64)',
    'static void ml_GdkPixbuf_serialize (value v, uintnat *wsize_32, uintnat *wsize_64)'
)

$text = $text.Replace(
    'static unsigned long ml_GdkPixbuf_deserialize (void *dst)',
    'static uintnat ml_GdkPixbuf_deserialize (void *dst)'
)

[System.IO.File]::WriteAllText(
    $src,
    $text,
    [System.Text.UTF8Encoding]::new($false)
)
```

Verify that the patched signatures are present:

```powershell
Select-String `
    -Path $src `
    -Pattern "ml_GdkPixbuf_serialize|ml_GdkPixbuf_deserialize" `
    -Context 0,1
```

## 6. Change the local `lablgtk` install target

On the tested setup, `lablgtk` compiled successfully after the source patch but its normal `make install` target failed with:

```text
Cannot use ocamlfind, use old-install.
```

Create a local OPAM package definition from the repository metadata:

```powershell
$opamFile = "$work\lablgtk.opam"

$meta = opam show lablgtk.2.18.14 --raw

[System.IO.File]::WriteAllLines(
    $opamFile,
    $meta,
    [System.Text.UTF8Encoding]::new($false)
)
```

Change the install action from:

```text
[make "install"]
```

to:

```text
[make "old-install"]
```

with:

```powershell
$text = [System.IO.File]::ReadAllText($opamFile)

$text = $text.Replace(
    '[make "install"]',
    '[make "old-install"]'
)

[System.IO.File]::WriteAllText(
    $opamFile,
    $text,
    [System.Text.UTF8Encoding]::new($false)
)
```

Verify:

```powershell
Select-String $opamFile -Pattern 'install:|old-install' -Context 0,2
```

## 7. Pin and install the patched `lablgtk`

Pin the package to the local source directory:

```powershell
opam pin add lablgtk "$work" --no-action --yes
```

Keep the required GTK `pkgconf` setting in the same PowerShell session:

```powershell
$env:PKG_CONFIG = 'pkgconf --personality=x86_64-w64-mingw32'
```

Install the pinned package in place:

```powershell
opam install lablgtk --inplace-build
```

If the package has already been successfully compiled in the local source tree and only the installation step needs to be repeated, OPAM also supports:

```powershell
opam install lablgtk --assume-built
```

The latter was used during the tested troubleshooting sequence after a successful build followed by a failed installation step.

Verify that OPAM records the package:

```powershell
opam list lablgtk
```

## 8. Expose the old-style LablGTK installation to `ocamlfind`

The successful `old-install` path placed the LablGTK findlib metadata below the switch's `lib\ocaml` directory. In the tested setup, `ocamlfind query lablgtk2` did not find it until `OCAMLPATH` was extended.

Set:

```powershell
$prefix = (opam var prefix --switch=proverif).Trim()
$env:OCAMLPATH = "$prefix\lib\ocaml"
```

Check:

```powershell
opam exec --switch=proverif -- ocamlfind query lablgtk2
```

This should now return the installed `lablgtk2` directory.

## 9. Install ProVerif

With the patched/pinned LablGTK installation visible to findlib:

```powershell
opam install --switch=proverif proverif.2.05
```

The tested installation completed with:

```text
installed proverif.2.05
Done.
```

Verify:

```powershell
opam exec --switch=proverif -- proverif -help
```

## 10. Using ProVerif in later PowerShell sessions

The tested setup did not rely on permanent OPAM shell activation.

For a new PowerShell session, activate the switch with:

```powershell
(& opam env --switch=proverif --set-switch) -split '\r?\n' |
    ForEach-Object { Invoke-Expression $_ }
```

Then restore the `OCAMLPATH` required by the patched LablGTK installation:

```powershell
$prefix = (opam var prefix --switch=proverif).Trim()
$env:OCAMLPATH = "$prefix\lib\ocaml"
```

ProVerif can then be called normally:

```powershell
proverif -help
```

Alternatively, individual commands can be run explicitly through the switch:

```powershell
opam exec --switch=proverif -- proverif -help
```

For commands that require the patched LablGTK findlib package, keep the `OCAMLPATH` setting above in the current session.

## Troubleshooting notes from the tested installation

### `opam depext` is not a known command

The ProVerif 2.05 manual still documents:

```text
opam depext ...
```

Current OPAM no longer requires that workflow. System dependency handling was integrated into OPAM itself in OPAM 2.1:

https://opam.ocaml.org/blog/opam-2-1-0/

### `GTK+ is required`

If `lablgtk` reports that GTK+ is missing even though OPAM installed the GTK2 configuration packages, check:

```powershell
opam exec -- pkgconf --personality=x86_64-w64-mingw32 --modversion gtk+-2.0
```

and ensure:

```powershell
$env:PKG_CONFIG = 'pkgconf --personality=x86_64-w64-mingw32'
```

is set before retrying the build.

### `Unbound module Genlex`

This occurred when trying to build the old LablGTK package in the OCaml 5.5.0 switch. The final tested setup instead uses the dedicated OCaml 4.14.4 `proverif` switch documented above.

### Win64 `ml_gdkpixbuf.c` incompatible-pointer-type errors

If errors mention the `serialize` / `deserialize` members of `ml_custom_GdkPixbuf`, apply the two `unsigned long` -> `uintnat` signature changes documented above.

### `sed: command not found`

During manual troubleshooting, directly invoking OPAM's internal Cygwin `make.exe` from PowerShell caused Cygwin utilities such as `sed` not to be on that manually launched build's `PATH`.

This is not necessary in the final procedure above. If manually invoking Cygwin build tools for debugging, the internal Cygwin directory is typically:

```powershell
$cygroot = "$env:LOCALAPPDATA\opam\.cygwin\root"
$env:PATH = "$cygroot\bin;$env:PATH"
```

The final OPAM-driven pinned build should manage its own internal build environment.