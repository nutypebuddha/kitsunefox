# kitsunefox release process

This directory holds the tooling for producing a GitHub Release that a
Linux user can download and run without a compiler, without the repo,
and without a warranty. It is repo-side material: the files here are
**not** included in the release artifact (see the exclusion policy).

## Assets

A release is exactly four files, uploaded to the same GitHub Release:

| file | purpose |
| --- | --- |
| `kitsunefox-<version>.tar.gz` | the artifact: product tree at a committed ref, byte-reproducible, single top-level dir `kitsunefox-<version>/` |
| `kitsunefox-<version>.tar.gz.sha256` | `sha256sum -c`-compatible checksum of the tarball |
| `kitsunefox-<version>.provenance.json` | build record: source commit/tree, epoch, exclusions, payload stats, builder tool versions, fork base |
| `verify.sh` | clean-machine verifier (POSIX sh + coreutils only; runs offline) |

Artifact contents are the product, not the repository:

- **included**: `user.js`, `userContent.css` (57 themes at root), `README.md`,
  `LICENSE`, `launcher/kitsunefox`, `launcher/kitsunefox.desktop`, and a
  generated `MANIFEST.sha256` (per-file hashes of everything else).
- **excluded** (recorded in provenance with source presence):
  - `kitsunefox/` — historical snapshot subtree, frozen since the initial
    commit (23 themes vs 57 at root); a stale duplicate.
  - `.gitignore` — repository maintenance file, not product.
  - `release/` — build/verify tooling, shipped as separate release assets.

## Building

From inside the repository (no git state is modified — no commit, no
tag, no push, no fetch):

```sh
release/build.sh                 # version = git describe of HEAD
release/build.sh --version v0.4.0
release/build.sh --ref v0.4.0 --version v0.4.0
release/build.sh --out /tmp/out  # default: <repo>/dist (gitignored)
```

The builder:

- sanity-checks the same launcher check the Wintermore push gate has
  registered (`sh -n launcher/kitsunefox` and the desktop file's presence);
- builds twice from the **committed** tree (never the dirty worktree) and
  `cmp`s the results — dist/ is only written when they are byte-identical;
- pins a single mtime (commit time) for every file, numeric root ownership,
  sorted entries, and `gzip -n`, so the artifact is reproducible;
- refuses the launcher check, a non-commit ref, or an invalid version.

Version strings allow `A-Z a-z 0-9 . _ -`.

## Verifying

On any Linux machine with `sh`, `tar`, `gzip`, and coreutils (no git, no
python, no network):

```sh
sh verify.sh kitsunefox-<version>.tar.gz kitsunefox-<version>.tar.gz.sha256
```

or, with the sidecar beside the tarball:

```sh
sh verify.sh kitsunefox-<version>.tar.gz
```

Then install exactly as README section 0 describes:

```sh
tar -xzf kitsunefox-<version>.tar.gz
cd kitsunefox-<version>
./launcher/kitsunefox        # or the .desktop file
```

`verify.sh` is fail-closed. Every failure increments a counter and the
exit status is 1; 0 means every check passed. It distinguishes
**EXTERNALLY ANCHORED** runs (a checksum source was present and matched)
from structure-only runs, and it prints a warning when no checksum
source was found.

## Trust model (read this before shipping)

Checksums make the release resistant to **corruption and mixed-up
assets**: if the tarball is truncated or the wrong asset is paired with
the wrong checksum, verification fails loudly. They do **not** protect
against a hostile publisher: anyone who can modify the GitHub Release can
replace all four files together, and the checksums plus provenance would
then agree with the tampered artifact. Provenance is builder-attested,
not cryptographically signed. This is the honest ceiling of what these
files claim.

## Publishing (manual, by the maintainer)

Nothing in `release/` touches git state or GitHub. Publishing is a
deliberate, separate human act:

1. Commit the release tooling and README changes, then push through the
   Wintermore pre-push gate (hook checks run and must pass).
2. Tag the release commit: `git tag v<version>`. Use a **lightweight tag**
   (plain commit pointer); the gate's v1 contract requires every pushed ref
   to carry the checked-out HEAD sha, which an annotated tag object can
   never do — annotated tags are unevidencable by this gate. Build
   `--version` should match the tag.
3. Run `release/build.sh` (default output: `<repo>/dist`).
4. In the GitHub UI create a Release for the tag and upload the four
   files. Do **not** auto-generate release notes from commits; write them
   by hand.
5. Verify on a clean machine (see above), ideally a disposable VM or
   container, using only the downloaded files.