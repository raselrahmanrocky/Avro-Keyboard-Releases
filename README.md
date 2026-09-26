<div align="center">

# 🇧🇩 Avro Keyboard — Release Hub

**The official home of Avro Keyboard installers, portable editions, and updates.**

*The most popular Unicode-compliant Bangla (Bengali) input method for Windows —
rebuilt for modern hardware, faster conversion, and zero-friction installation.*

**[⬇️ Download the Latest Release](https://github.com/raselrahmanrocky/Avro-Keyboard-Releases/releases)**

</div>

---

## 🧭 Quick Navigation

| | |
| --- | --- |
| 📦 **Which build do I need?** | [Edition & Architecture Comparison](#-edition--architecture-comparison) |
| ⚡ **What's new in v6?** | [Before vs. After](#-before-vs-after-the-v6-jump) |
| ✨ **Feature deep dives** | [Core Upgrades & New Features](#-deep-dive-core-upgrades--new-features) |
| 🛠️ **Something broke?** | [Support & Feedback](#-support--feedback) |

> 💡 **New to Avro Keyboard?** Grab the **64-bit installer** below, run it, and start
> typing Bangla in under a minute. Everything else on this page is optional reading.

---

## 📦 Edition & Architecture Comparison

Every release ships **four builds**. Pick the row that matches how you use your computer —
the differences are real, and the wrong choice is the most common support question we get.

| Build | Format | Architecture | Best for | Who should download it? |
| --- | --- | --- | --- | --- |
| **`win64-setup`** | Installer (`.exe`) | **64-bit** | Daily desktop use on a modern PC | ✅ **Most users — start here.** Runs natively on virtually every Windows 10/11 machine, installs fonts, Start Menu shortcuts, and shared dictionaries for you. |
| **`win32-setup`** | Installer (`.exe`) | 32-bit | Older or locked-down systems | Legacy 32-bit Windows editions, or machines where 64-bit components cause conflicts. Same features, smaller memory ceiling. |
| **`win64-portable`** | Archive (`.zip`) | **64-bit** | USB drives & no-admin machines | 🚀 **USB / shared-PC users.** Unzip anywhere and run — no installer, no admin rights, no traces left on the host machine. |
| **`win32-portable`** | Archive (`.zip`) | 32-bit | Portable on older hardware | The portable experience for 32-bit systems. Ideal for reviving an old laptop from a thumb drive. |

### 🎯 Which one do I pick?

> **Standard desktop user?** → **`win64-setup`**. Done.
>
> **Carrying Avro on a USB drive?** → **`win64-portable`**. It never touches the Windows
> Registry or `AppData` — plug it into any PC, type, unplug, and nothing is left behind.
>
> **On a 32-bit copy of Windows?** → use the `win32` variants instead. Not sure?
> Press `⊞ Win + R`, type `winver`, and check your system type under **Settings → System → About**.

### 🛡️ Every download is verified

Release archives include published **SHA-256 checksums**. If you're distributing Avro Keyboard
inside an organization, your users can confirm the file they received is byte-for-byte identical
to the one we shipped.

---

## ⚡ Before vs. After: The v6 Jump

v6 is not a version bump — it's a re-architecture. Here's what actually changed in your
daily workflow.

| Your workflow | 🔙 Before | 🚀 Now |
| --- | --- | --- |
| **Getting the right build** | One ambiguous download; guess whether your PC is supported. | **Four clearly named builds** — pick your architecture and install style in seconds. |
| **Running from a USB drive** | "Portable" builds still wrote to the Registry and `AppData`, polluting every machine you touched. | **True Portable Mode** — settings, dictionaries, skins, and fonts live beside the `.exe`. Zero footprint. |
| **Converting Unicode ⇄ ANSI/Bijoy text** | Hunt through folders or the Start Menu for a separate converter tool; duplicate windows stacked up. | The **converter ships inside Avro** and is a single keystroke away through the global hotkey system — no digging, no clutter. |
| **Switching ANSI encoding versions** | Slow, clunky switching with stutter on first use. | **Instant, zero-allocation engine switching** with a warm cache — the first use is as fast as the last. |
| **Installing layouts & skins** | Manually download a file, unzip it, find the right folder, hope it loads. | **In-App Resource Downloader** — browse, click, and it verifies and installs itself. |
| **Keeping Avro updated** | Check the website, match version numbers by eye, re-download the wrong file. | **Automatic update checks** with architecture-aware, link-verified offers — including an opt-in **beta channel**. |
| **System resources** | 32-bit-only builds; heavier memory footprint during long sessions. | **Native 32-bit & 64-bit builds** with lazy-loaded data and idle memory release. |

---

## 🚀 Deep Dive: Core Upgrades & New Features

### 🔁 Standalone Converter Integration

The Avro Text Converter is no longer a tool you go looking for — it ships as part of the
package and launches straight from the tray menu, the main menu, or its own Start Menu entry.
Because Avro's **global hotkey system** now records and validates shortcuts across the entire
application, you can bind the converter (or the ANSI version picker, layout picker, or speller)
to a keystroke that works while you're inside *any* program — Word, your browser, a code editor.

The hotkey engine handles the details for you: it **detects conflicts before saving**,
deduplicates overlapping combinations, and keeps the tray menu and on-screen pickers in perfect
sync, so the shortcut you set is always the shortcut that fires. Conversion itself now runs
**off the main interface thread with background processing**, so pasting a large document and
converting it never freezes the window — and the result is available the moment you need it.

### 🌐 Modern ANSI Encoding Engine

The engine that converts Unicode Bangla into legacy ANSI/Bijoy encodings has been rebuilt
from the ground up. The old built-in mapping table is gone; every encoding version is now a
**first-class, file-based mapping** (V1 through V4) that loads on demand and releases itself
when idle. The practical result is **flawless Unicode conversion across all supported ANSI
versions**, with correct handling of the conjuncts, reph, and pre-base kar cases that used to
mis-render.

Three changes make it feel instant:

- ⚡ **Engine warming** — mappings are prepared ahead of your first keystroke, so there is no
  cold-start stutter.
- ⚡ **Persistent caching** — converted mapping data survives restarts instead of being rebuilt
  every launch.
- ⚡ **Zero-allocation switching** — flipping between ANSI versions swaps state in place, with no
  memory churn mid-sentence.

Backspace is now **grapheme-aware** in both Unicode and ANSI modes: it removes a whole visual
cluster instead of leaving orphaned combining marks behind, which is exactly what you expect
when you're editing at speed.

### 📁 True Portable Mode

Portable used to mean "an installer you didn't run." It now means **the application genuinely
runs without modifying the Windows Registry or `AppData`** — settings live in a single XML file
next to the executable, dictionaries, skins, layouts, and fonts resolve from inside the folder,
and the About box honestly labels the build `(Portable)`.

That makes it:

- ✅ **Perfect for USB drives** — move between machines without dragging settings residue along.
- ✅ **Safe on managed/shared PCs** — no admin rights required, no writes to protected locations.
- ✅ **Clean to remove** — delete the folder and the application is gone; nothing lingers.
- ✅ **Update-aware** — portable builds automatically prefer portable downloads when a new
  version is offered, so you're never handed an installer by mistake.

### 🧩 Native 32-bit & 64-bit Separation

Avro is now compiled and shipped as **genuinely separate 32-bit and 64-bit products**, not one
binary running through a compatibility layer. Each build manages memory against its own address
space and is verified at packaging time to confirm it really is the architecture its filename
claims.

Why you care:

- **Better memory behaviour** — the 64-bit build uses native pointers and a larger address space,
  eliminating the page-file pressure and truncation edge cases that 32-bit builds hit under load.
- **Real system stability** — no WoW64 translation layer between Avro and your keyboard input,
  which matters for a process that hooks keystrokes all day long.
- **Correct matching** — the update system downloads the build that matches the process you're
  actually running, so a 64-bit install never gets offered a 32-bit update.

### 📥 In-App Resource Downloader & Auto-Updates

Two long-standing friction points — finding add-ons, and staying current — are now handled
inside the application itself.

**Download Resources** is a full in-app browser for layouts, skins, and ANSI mapping packs.
You browse categories, pick what you want, and Avro downloads it in the background with live
progress, **verifies every file with SHA-256 before it touches your system**, and installs it
into the correct folder for the edition you're running. New ANSI mappings and skins are picked
up automatically the moment they land — no restart, no manual copy-paste — and fonts register
for your user account without an elevation prompt. If no ANSI mapping is installed at all, the
tray nudges you with an actionable notification instead of failing silently.

**Automatic updates** check the official release channel and offer new versions in place. The
download link is **verified live before the prompt appears**, so you'll never be sent to a dead
or wrong URL; architecture-appropriate downloads are selected for you; and a **beta channel
toggle** lets early adopters receive pre-release builds while everyone else stays on stable.

---
✨ **New Features**
- **Application-wide theming and palette system** for a consistent interface.
- **Tray "Select ANSI Encoding" menu** with full synchronization across every picker.
- **Per-layout icons** in mapping containers, with unified rendering between tray and picker.
- **Shield-keyed asset protection** — encoding data is obfuscated with per-build keying and self-test gates that run before the engine is trusted.

🚀 **Performance & Improvements**
- **File-based mapping engine** — the built-in default table was retired in favour of loading mappings on demand.
- **Natural sort ordering** across encoding menus and pickers (V2 before V10, finally).
- **Picker and popup stability** reworked for reliable focus and positioning.

🛠️ **Bug Fixes**
- **ANSI V3 and V4 mapping tables updated** to resolve incorrect glyph output.
- **Menu synchronization defects** fixed between the tray, the picker, and the options dialog.
---

## 🛠️ Support & Feedback

Different problems belong in different places — using the right queue gets you a faster answer.

| I want to… | Open an issue at |
| --- | --- |
| 🐞 Report a **typing, conversion, new feature, broken download, wrong build, installer, or portable problem or application bug** | **[Avro-Keyboard-Releases Issues](https://github.com/raselrahmanrocky/Avro-Keyboard-Releases/issues)** |
| ❓ Ask a **usage question** or show off your setup | **[Avro Users Community on Telegram](https://t.me/AvroUsersCommunity)** |

> **Before reporting an issue:**
> - Search existing issues to avoid duplicates — it's the fastest way to get a fix.
> - Include your **Windows version**, **which build you downloaded** (`win64-setup`, `win32-portable`, …),
>   and **Avro's version** from the About box.
> - For download problems, paste the **exact URL or file name** you tried.
> - A short screen recording or a sample of mis-converted text helps us reproduce instantly.

---

<div align="center">

**[⬇️ Download Avro Keyboard](https://github.com/raselrahmanrocky/Avro-Keyboard-Releases/releases)** ·
**[💬 Community](https://t.me/AvroUsersCommunity)**

*Avro Keyboard is open source software licensed under the Mozilla Public License 2.0.*

</div>
