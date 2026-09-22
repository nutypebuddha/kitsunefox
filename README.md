# kitsunefox 🦊

A hardened + themed Firefox configuration focused on privacy, reduced browser noise, and a customizable Firefox interface.

`kitsunefox` combines:

- a hardened `user.js`
- multiple Firefox `userChrome.css` themes
- a cosmetic `userContent.css` cleanup layer

It is **not** a Firefox fork and **not** a browser extension.

## v0.3.0

61 styles (57 theme dirs + 4 Catppuccin root files) + hardened `user.js` + cosmetic `userContent.css`. New in v0.3.0: 24 compact themes — `coffee-shops`, `darcula`, `dotrb`, `dracula`, `evergarden`, `jade-necklace`, `japan-night`, `liminal`, `neo-sploosh`, `onedark-pro`, `rainbow`, `shades-of-jade`, `solarized`, `solarized-dark`, `solarized-light`, `solarized-osaka`, `travels`, `void`, `vs-code-dark`, `vs-code-dark-2019`, `vs-code-light`, `vs-code-light-2019`, `vs-code-minimal`, `vs-code-seti`. No functional change to `user.js`/`userContent.css` from v0.2.0.

## v0.2.0

33 themes + hardened `user.js` + cosmetic `userContent.css`. New in v0.2.0: `retro82`, `cp437-dos`, `hackerman`, `sakura` (#ff9cae), `zenburn`, `tokyo-night-storm`, `material3-expressive`, `oceanic-next`, `gruvbox-material`, `moonlight`.

```text
kitsunefox/
├── user.js
├── userContent.css
├── userChrome-*.css          # catppuccin frappe/latte/macchiato/mocha
└── <theme>/userChrome.css    # 57 theme directories (see below)
````

### Tested on

* Firefox 155
* Waterfox 6.7.3
* Arch Linux

Other Firefox versions and operating systems may work, but have not yet been explicitly tested.

---

## Features

### Hardened Firefox configuration

`user.js` applies a stricter privacy-oriented Firefox configuration inspired by the Arkenfox project.

Current hardening includes changes around:

* telemetry and Firefox studies
* sponsored content
* speculative networking and prefetching
* browser history and shutdown cleanup
* fingerprinting resistance
* WebRTC and media APIs
* WebGL
* HTTPS-only behavior
* password and form storage
* URL-bar suggestions
* geolocation
* push notifications
* DRM
* autoplay

The file is commented so the purpose and expected breakage of stricter settings can be reviewed directly.

### Firefox interface themes

kitsunefox includes 61 `userChrome.css` styles for Firefox's own interface (57 theme dirs + 4 Catppuccin root files).

| Theme | Vibe |
|---|---|
| `amberbyte` | warm amber |
| `arc-blueberry` | Arc blue |
| `ayu` / `ayu-dark` / `ayu-light` / `ayu-mirage` | Ayu variants |
| `base16` / `base16-light` | Base16 |
| `bluedotrb` | blue dot |
| `coffee-shops` *(new in v0.3.0)* | warm coffeehouse |
| `cp437-dos` *(new in v0.2.0)* | DOS amber/CP437 terminal |
| `cyberpunk` | neon 2077 |
| `darcula` *(new in v0.3.0)* | Darcula IDE |
| `dotrb` *(new in v0.3.0)* | dot red-blue |
| `dracula` *(new in v0.3.0)* | Dracula |
| `everforest` | forest |
| `evergarden` *(new in v0.3.0)* | evergarden |
| `github-dark` | GitHub dark |
| `gruvbox` / `gruvbox-light` / `gruvbox-v2` / `gruvbox-material` *(new)* | Gruvbox variants |
| `hackerman` *(new)* | green phosphor |
| `jade-necklace` *(new in v0.3.0)* | jade green |
| `japan-night` *(new in v0.3.0)* | Japan night |
| `kanagawa` | Kanagawa wave |
| `liminal` *(new in v0.3.0)* | liminal space |
| `material3-expressive` *(new)* | M3 Expressive |
| `monokai` | Monokai |
| `moonlight` *(new)* | indigo moonlight |
| `neo-sploosh` *(new in v0.3.0)* | neon sploosh |
| `nord` | Nord |
| `oceanic-next` *(new)* | Oceanic Next |
| `onedark` | One Dark |
| `onedark-pro` *(new in v0.3.0)* | One Dark Pro |
| `osaka-jade` | Osaka jade |
| `rainbow` *(new in v0.3.0)* | rainbow |
| `retro82` *(new)* | 80s synthwave |
| `rose-pine` | Rosé Pine |
| `sakura` *(new)* | #ff9cae soft pink |
| `shades-of-jade` *(new in v0.3.0)* | jade shades |
| `solarized` / `solarized-dark` / `solarized-light` / `solarized-osaka` *(new in v0.3.0)* | Solarized variants |
| `solitude` | solitude |
| `tokyo-night` / `tokyo-night-storm` *(new)* | Tokyo Night variants |
| `travels` *(new in v0.3.0)* | travels |
| `vantablack` | pure black |
| `void` *(new in v0.3.0)* | void black |
| `vs-code-dark` / `vs-code-dark-2019` / `vs-code-light` / `vs-code-light-2019` / `vs-code-minimal` / `vs-code-seti` *(new in v0.3.0)* | VS Code variants |
| `zenburn` *(new)* | low-contrast Zenburn |
| `userChrome-frappe/latte/macchiato/mocha.css` | Catppuccin |

Pick one: `cp <theme>/userChrome.css chrome/userChrome.css` (see Installation §5).

These can change Firefox UI elements such as:

* tabs
* URL bar
* navigation bar
* panels
* bookmarks bar
* sidebar
* borders
* highlights
* interface colors

### Cosmetic page cleanup

`userContent.css` hides many common webpage annoyances, including:

* advertising containers
* sponsored content
* cookie and consent banners
* newsletter popups
* floating video
* chat/support widgets
* push-notification prompts
* some anti-adblock overlays
* other common page clutter

This is **cosmetic filtering only**.

CSS can hide page elements, but it cannot prevent their network requests.

For actual request blocking, use a content blocker such as uBlock Origin.

---

# Installation

A fresh Firefox profile is recommended.

## 0. From a release archive

The GitHub Release page carries an archive plus a checksum
(`kitsunefox-<version>.tar.gz.sha256`) and `verify.sh` (needs only `sh`,
`tar`, `gzip`, and coreutils — no git, no Python, no network). With all
three beside each other:

```text
sh verify.sh kitsunefox-<version>.tar.gz kitsunefox-<version>.tar.gz.sha256
tar -xzf kitsunefox-<version>.tar.gz
cd kitsunefox-<version>
```

The archive unpacks to a single directory containing everything this
README documents: `user.js`, the theme directories, `userContent.css`,
`README.md`, `LICENSE`, and `launcher/`. Where the steps below say
`kitsunefox/user.js` or `launcher/kitsunefox`, read that as the unpacked
directory in its place (`kitsunefox-<version>/`). The release tooling
under `release/` is deliberately excluded from the archive.

## 1. Locate your Firefox profile

Open:

```text
about:profiles
```

Find the profile you want to use and open its **Root Directory**.

## 2. Install the hardened configuration

Copy:

```text
kitsunefox/user.js
```

into the profile root, next to Firefox's `prefs.js`.

Restart Firefox.

`user.js` is applied when Firefox starts.

## 3. Enable custom Firefox CSS

Open:

```text
about:config
```

Find:

```text
toolkit.legacyUserProfileCustomizations.stylesheets
```

and set it to:

```text
true
```

## 4. Create the chrome directory

Inside the Firefox profile root, create:

```text
chrome/
```

## 5. Choose a theme

Pick the kitsunefox `userChrome` stylesheet you want.

For example:

```text
kitsunefox/userChrome-mocha.css
```

Copy it to:

```text
chrome/userChrome.css
```

Firefox expects the active interface stylesheet to be named exactly:

```text
userChrome.css
```

Restart Firefox.

## 6. Optional: install the page cleanup layer

Copy:

```text
kitsunefox/userContent.css
```

to:

```text
chrome/userContent.css
```

Restart Firefox again.

---

## 7. Optional: Linux launcher

A small POSIX `sh` launcher is included at `launcher/kitsunefox`.

It resolves a browser command and optionally a named profile, then execs the
browser with all passed arguments preserved. It writes nothing and never
creates or mutates profiles.

* `KITSUNEFOX_BROWSER` — optional. Override the browser command (a single
  executable name or absolute path). Default: the first of `firefox`,
  `firefox-esr`, `waterfox` found in `PATH`.
* `KITSUNEFOX_PROFILE` — optional. The Firefox Profile Manager **name** of the
  profile to launch, passed through with `-P NAME`. It is the
  profile *name* (as shown in `about:profiles` / the Profile Manager) — not
  the `--name` argument, and not a filesystem path for `--profile`. The
  profile must already exist in the browser; the launcher does not create it.
  Unset: launches the browser's default/current profile.

To use it:

```text
cp launcher/kitsunefox ~/.local/bin/kitsunefox
chmod +x ~/.local/bin/kitsunefox
```

Optional desktop entry:

```text
cp launcher/kitsunefox.desktop ~/.local/share/applications/
```

Graphical desktop sessions may not include `~/.local/bin` in `PATH`. If the
desktop entry cannot find `kitsunefox`, edit its `Exec=` line to use the
launcher's absolute path, for example:

```text
Exec=/home/USER/.local/bin/kitsunefox %U
```

The desktop entry launches the browser without forcing a profile. To launch a
named profile through it, set `KITSUNEFOX_PROFILE` in the `Exec=` line:

```text
Exec=env KITSUNEFOX_PROFILE=NAME kitsunefox %U
```

Remove the entry by deleting `~/.local/share/applications/kitsunefox.desktop`.

---

# Important compatibility notes

kitsunefox intentionally uses some aggressive privacy settings.

Depending on your needs, the default `user.js` can break or disable functionality including:

* WebRTC calls and browser screen sharing
* WebGL-based sites and 3D applications
* DRM services such as some streaming platforms
* browser password saving
* browser autofill
* browser history
* web push notifications
* gamepad APIs
* geolocation
* autoplay
* some cross-site login or embed flows

`privacy.resistFingerprinting` and letterboxing are also enabled.

Review `user.js` before using it if compatibility is more important to you than maximum hardening.

---

# Customization

The simplest way to customize kitsunefox is to treat the repository files as a starting point.

For hardening changes, edit your local copy of:

```text
user.js
```

For interface changes, modify or replace:

```text
chrome/userChrome.css
```

For webpage cosmetic changes:

```text
chrome/userContent.css
```

Keep a backup of your changes before replacing files with a newer kitsunefox release.

---

# Removing kitsunefox

## Remove the interface theme

Delete:

```text
chrome/userChrome.css
```

and restart Firefox.

## Remove page filtering

Delete:

```text
chrome/userContent.css
```

and restart Firefox.

## Stop applying the hardened configuration

Remove:

```text
user.js
```

from the Firefox profile root.

Restart Firefox.

Some preferences previously written by `user.js` may remain stored in the profile.

For a completely clean state, creating a new Firefox profile is the simplest option.

---

# Known limitations

* `userChrome.css` relies on Firefox's legacy browser UI customization support and may require maintenance after Firefox UI changes.
* `userContent.css` performs cosmetic hiding rather than network-level blocking.
* Strict `user.js` settings intentionally reduce compatibility with some sites and browser features.
* v0.3.0 adds 24 compact themes; no functional change to `user.js`/`userContent.css` from v0.2.0 (tested on Firefox 155 / Waterfox 6.7.3, Arch).

No other known bugs are currently documented.

---

# Credits

The kitsunefox privacy configuration is inspired by the excellent [arkenfox user.js](https://github.com/arkenfox/user.js) project.

The current `user.js` documents preferences checked against Arkenfox v144 while marking kitsunefox-specific stricter or additional settings separately.

---

# License

MIT.

See [`LICENSE`](LICENSE).

---

**kitsunefox**

Harden Firefox underneath.
Make it yours on top. 🦊
