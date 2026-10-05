# VMPKG 🐧 — Self-Contained Linux Package Manager

**VMPKG** is a cross-distribution, fully self‑contained **user-space package manager** for Linux.

It does **not** wrap or depend on system package managers like `apt`, `pacman`, `dnf`, `yum`, `zypper`, `apk`, `xbps`, or `emerge`.  
Instead, it manages its own registry, cache, manifests, and installation tree inside the user’s home directory.

If you have **Linux + Bash + curl/wget + tar (optionally unzip)** — **VMPKG works out of the box**.

---

<p align="center">
  <a href="https://github.com/omar9devx/vmpkg/actions/workflows/ci.yml">
    <img src="https://github.com/omar9devx/vmpkg/actions/workflows/ci.yml/badge.svg" alt="CI">
  </a>
  <a href="https://github.com/omar9devx/vmpkg">
    <img src="https://img.shields.io/badge/version-1.3.0-blue.svg" alt="Version: 1.3.0">
  </a>
  <a href="https://github.com/omar9devx/vmpkg">
    <img src="https://img.shields.io/badge/platform-linux-333333?logo=linux&logoColor=ffffff" alt="Platform: Linux">
  </a>
  <a href="https://github.com/omar9devx/vmpkg">
    <img src="https://img.shields.io/badge/shell-bash-4EAA25?logo=gnu-bash&logoColor=ffffff" alt="Shell: Bash">
  </a>
  <a href="https://github.com/omar9devx/vmpkg/blob/main/LICENSE">
    <img src="https://img.shields.io/badge/license-GPL-blue.svg" alt="License: MIT">
  </a>
  <a href="https://github.com/omar9devx/vmpkg">
    <img src="https://img.shields.io/badge/type-self--contained%20pkg%20manager-ff6f00" alt="Self-contained package manager">
  </a>
</p>

---

## 🚀 What Is VMPKG?

Linux distributions each come with different native package managers:

- `apt` (Debian/Ubuntu)
- `pacman` (Arch-based)
- `dnf` / `yum` (Fedora / RHEL)
- `zypper` (openSUSE)
- `apk` (Alpine)
- `xbps` (Void)
- `emerge` (Gentoo)

These tools:

- require root privileges  
- modify system-wide state  
- behave differently across distros  

**VMPKG is not one of them.**

### VMPKG is:

- A self-contained package manager  
- Runs fully inside **user space**  
- Stores everything under `~/.vmpkg` (or `$VMPKG_ROOT`)  
- Installs packages from **archives** (`.tar.gz`, `.tar`, `.zip`)  
- Creates symlinks for executables into `~/.local/bin` (or `$VMPKG_BIN`)  
- Zero interaction with system package managers  
- Zero system-wide changes  

It is ideal for:

- Developers  
- Multi-distro workflows  
- Containers / WSL  
- Environments without root  
- Dotfiles-based portability  

---

## ✨ Features

- ✔ **User-space package manager** — no root needed  
- ✔ Works on **all Linux distributions**  
- ✔ **Self-contained registry & manifests**  
- ✔ **SHA256 checksum verification** for package integrity  
- ✔ Automatic package upgrade check & install (`vmpkg upgrade`)  
- ✔ Supports `.tar.gz`, `.tar.xz`, `.tar.bz2`, `.tar`, `.zip`  
- ✔ Robust MIME-type detection using `file` and extensions  
- ✔ Predictable directory structure  
- ✔ Pretty CLI output (colors + icons + timestamps)  
- ✔ Minimal dependencies (Bash + curl/wget + tar)  
- ✔ Automated regression test suite & GitHub Actions CI  
- ✔ Includes system helper commands  

---

## 🌐 Supported Platforms

VMPKG works on **any Linux distribution**, including:

- Debian / Ubuntu / Mint / PopOS / Kali  
- Arch / Manjaro / EndeavourOS  
- Fedora / RHEL / CentOS  
- openSUSE  
- Alpine Linux  
- Void Linux  
- Gentoo  
- WSL (Windows Subsystem for Linux)  
- Containers (Docker / Podman)  
- Cloud VMs and minimal servers  

Requirements:

- Linux  
- bash  
- curl **or** wget  
- tar (+ unzip for zip archives)

> VMPKG **does not replace** your system’s package manager — it simply installs user-space tools portably.

---

## 🧱 Architecture Overview

Below is the internal flow of an install operation:

```
              ┌────────────────────────┐
              │  Registry (~/.vmpkg)   │
              │ name|ver|url|desc      │
              └─────────┬──────────────┘
                        │
            vmpkg install <name>
                        │
                        ▼
            ┌───────────────────────┐
            │ Download archive      │
            │ → ~/.vmpkg/cache      │
            └─────────┬─────────────┘
                      │
                      ▼
            ┌───────────────────────┐
            │ Extract archive to    │
            │ ~/.vmpkg/pkgs/<pkg>   │
            └─────────┬─────────────┘
                      │
                      ▼
            ┌───────────────────────┐
            │ Detect bin/ directory │
            │ Symlink to $VMPKG_BIN │
            │ (default ~/.local/bin)│
            └─────────┬─────────────┘
                      │
                      ▼
            ┌───────────────────────┐
            │ Available via PATH    │
            └───────────────────────┘
```

Directory structure:

```
~/.vmpkg/
   registry
   db/
      <name>.manifest
   cache/
      <name>-<version>.pkg
   pkgs/
      <name>-<version>/
```

---

## 📦 Package Registry Format

The registry file is simple, fast, and human-readable:

```
name|version|url|description|[sha256]
```

Examples:

```
bat|0.24.0|https://example.com/bat.tar.gz|cat clone with wings|d68ffad399d25514f76ba202cfbe9c4b7b25055b46e311394a5303c7343e8ea2
rg|14.1.0|https://example.com/rg.tar.gz|fast code search
lazygit|0.44.0|https://example.com/lazygit.tar.gz|git TUI
```

> **Note:** If `sha256` is provided, `vmpkg` automatically verifies the downloaded archive's checksum against it before extraction.

Expected archive layout:

```
mytool/
  bin/
    mytool
  lib/
  share/
```

Or:

```
mytool-x86_64/
  bin/
    mytool
```

---

## 🏗 Installation

### User-Space Install (No root required — Recommended):

```bash
curl -fsSL https://raw.githubusercontent.com/omar9devx/vmpkg/main/installscript.sh | bash
```
> Installs binary to `~/.local/bin/vmpkg`. Ensure `~/.local/bin` is in your `$PATH`.

### System-Wide Install (Root):

```bash
curl -fsSL https://raw.githubusercontent.com/omar9devx/vmpkg/main/installscript.sh | sudo bash
```
> Installs binary to `/usr/local/bin/vmpkg`.

---

## 🛠 Maintenance

```bash
curl -fsSL https://raw.githubusercontent.com/omar9devx/vmpkg/main/updatescript.sh | sudo bash
```

Options include:

- Update VMPKG  
- Repair installation  
- Reinstall  
- Delete  
- Delete + backup  

---

## 📚 Core Usage

```bash
vmpkg init
vmpkg register <name> <version> <url> [description...] [sha256]
vmpkg install <name>
vmpkg reinstall <name>
vmpkg upgrade [name]
vmpkg remove <name>

vmpkg list
vmpkg search <pattern>
vmpkg show <name>

vmpkg clean
vmpkg doctor
```

---

## 🔥 Real-World Examples

### Neovim

```bash
vmpkg register neovim 0.10.0   "https://example.com/nvim-linux.tar.gz"   "Modern vim editor"

vmpkg install neovim
```

### ripgrep

```bash
vmpkg register rg 14.1.0   "https://example.com/ripgrep.tar.gz"   "Fast grep alternative"

vmpkg install rg
```

### LazyGit

```bash
vmpkg register lazygit 0.44.0   "https://example.com/lazygit.tar.gz"   "Terminal UI for git"

vmpkg install lazygit
```

---

## 🧠 System Helpers

```bash
vmpkg sys-info
vmpkg kernel
vmpkg disk
vmpkg mem
vmpkg top
vmpkg ps
vmpkg ip
```

---

## 🌍 Environment Variables

- `VMPKG_ROOT` — base directory (default `~/.vmpkg`)
- `VMPKG_BIN` — where symlinks go (default `~/.local/bin`)
- `VMPKG_ASSUME_YES=1` — auto-confirm prompts
- `VMPKG_DRY_RUN=1` — preview only
- `VMPKG_DEBUG=1` — verbose debug output
- `VMPKG_NO_COLOR=1` — disable colors
- `VMPKG_QUIET=1` — suppress info logs

---

## ❓ FAQ

### Does VMPKG replace my system package manager?
No — it does not modify system packages.

### Does it require sudo?
No — except optionally for installation into a system directory.

### Does it use any backend manager?
No — VMPKG is 100% independent.

### Where are packages stored?
Inside `~/.vmpkg` and `$VMPKG_BIN`.

### Can I use it in Docker or WSL?
Yes — it's ideal for that.

---

## 📌 Summary

- VMPKG is a **self-contained user-space package manager**  
- Works on *all Linux distros*  
- Does **not** depend on system package managers  
- Installs software from portable archives  
- Perfect for multi-distro setups, development, containers, and rootless systems

