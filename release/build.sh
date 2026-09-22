#!/bin/sh
# kitsunefox release builder.
#
# Produces a byte-reproducible release artifact from the COMMITTED tree at a
# git ref, plus checksum/provenance sidecars:
#
#   dist/kitsunefox-<version>.tar.gz            the release artifact
#   dist/kitsunefox-<version>.tar.gz.sha256     sha256sum -c compatible sidecar
#   dist/kitsunefox-<version>.provenance.json   build provenance record
#   dist/verify.sh                              copy of the clean-machine verifier
#
# Reproducibility: builds twice, requires byte-identical results, and only
# then writes dist/. Determinism comes from git-archive content + fixed
# mtimes (SOURCE_DATE_EPOCH = commit time) + normalized ownership/modes +
# gzip -n. Provenance JSON records build facts (including a wall-clock
# built_at); the ARTIFACT is the reproducible object.
#
# This script performs NO git state changes: no commit, no tag, no push,
# no fetch. It is safe alongside the Wintermore pre-push gate (the gate
# runs at push time; building never pushes).
#
# Exclusion policy (artifact = product, not repository):
#   kitsunefox/   historical snapshot subtree, frozen since the initial
#                 commit (23 themes vs 57 at root); a stale duplicate
#   .gitignore    repository maintenance file
#   release/      build/verify tooling, shipped as separate release assets
# Each exclusion is recorded in the provenance JSON with its source presence.
#
# Requirements: POSIX sh, GNU tar, gzip, git, GNU coreutils/findutils.
# Usage: release/build.sh [--version V] [--ref REF] [--out DIR]

set -eu
export LC_ALL=C
umask 022

die() { printf 'build.sh: error: %s\n' "$*" >&2; exit 1; }
step() { printf 'build.sh: %s\n' "$*"; }

usage() {
    cat <<'EOF'
usage: release/build.sh [--version V] [--ref REF] [--out DIR]

  --version V  version string for artifact names (default: git describe
               of the ref). Allowed characters: A-Z a-z 0-9 . _ -
  --ref REF    git ref to build from (default: HEAD). The artifact always
               comes from the COMMITTED tree, never the dirty worktree.
  --out DIR    output directory (default: <repo>/dist)

Reads git state only; never modifies commits, tags, remotes, or refs.
EOF
}

VERSION=''
REF='HEAD'
OUT=''
while [ $# -gt 0 ]; do
    case $1 in
        --version) [ $# -ge 2 ] || die '--version needs a value'; VERSION=$2; shift 2 ;;
        --ref)     [ $# -ge 2 ] || die '--ref needs a value';     REF=$2;     shift 2 ;;
        --out)     [ $# -ge 2 ] || die '--out needs a value';     OUT=$2;     shift 2 ;;
        -h|--help) usage; exit 0 ;;
        *)         die "unknown argument: $1 (see --help)" ;;
    esac
done

command -v git >/dev/null 2>&1 || die 'git is required'
REPO=$(git rev-parse --show-toplevel 2>/dev/null) ||
    die 'run this script inside the kitsunefox repository'
cd "$REPO"

for t in tar gzip sha256sum find sort sed awk cmp mktemp cut wc tr date cp rm mkdir chmod; do
    command -v "$t" >/dev/null 2>&1 || die "missing required tool: $t"
done
tar --version 2>/dev/null | head -n 1 | grep -q 'GNU tar' ||
    die 'GNU tar is required (--sort=name, --mtime, --owner)'

# Pre-build sanity: the same check the Wintermore push gate has registered
# for this repo (gate.py DEFAULT_CHECK_REGISTRY["kitsunefox-launcher"]).
sh -n launcher/kitsunefox || die 'push-gate check failed: sh -n launcher/kitsunefox'
test -f launcher/kitsunefox.desktop ||
    die 'push-gate check failed: test -f launcher/kitsunefox.desktop'

COMMIT=$(git rev-parse --verify "${REF}^{commit}") || die "cannot resolve ref: $REF"
if [ -z "$VERSION" ]; then
    VERSION=$(git describe --tags --always "$COMMIT") || die 'git describe failed'
fi
case $VERSION in
    ''|*[!A-Za-z0-9._-]*) die "invalid version '$VERSION' (allowed: A-Z a-z 0-9 . _ -)" ;;
esac

SDE=$(git log -1 --format=%ct "$COMMIT") || die 'cannot read commit timestamp'
TREE=$(git rev-parse "${COMMIT}^{tree}") || die 'cannot read commit tree'
COMMIT_DATE=$(git log -1 --format=%cI "$COMMIT") || die 'cannot read commit date'
TOP="kitsunefox-$VERSION"
FILE="$TOP.tar.gz"

STATUS=$(git status --porcelain 2>/dev/null) || die 'git status failed'
if [ -z "$STATUS" ]; then
    CLEAN=true
    DIRTY_COUNT=0
else
    CLEAN=false
    DIRTY_COUNT=$(printf '%s\n' "$STATUS" | wc -l | tr -d ' ')
fi

step "commit   $COMMIT"
step "version  $VERSION"
step "epoch    $SDE (commit time; all artifact mtimes)"
step "worktree $CLEAN ($DIRTY_COUNT path(s) differ from HEAD)"

TMP=$(mktemp -d "${TMPDIR:-/tmp}/kitsunefox-build.XXXXXX") || die 'mktemp failed'
cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT
trap 'cleanup; exit 130' INT
trap 'cleanup; exit 143' TERM

# Payload statistics, refreshed by each build_once run (both runs see the
# same content; the final byte-compare of the two tarballs is the authority).
PAYLOAD_FILES=0
PAYLOAD_BYTES=0
MANIFEST_SHA=''

build_once() {
    _out=$1
    _stage=$(mktemp -d "$TMP/stage.XXXXXX") || die 'mktemp stage failed'
    _root="$_stage/root"
    mkdir "$_root"

    git archive --format=tar --prefix="$TOP/" "$COMMIT" > "$_stage/source.tar" ||
        die 'git archive failed'
    tar -xf "$_stage/source.tar" -C "$_root" || die 'extract of git archive failed'
    _top="$_root/$TOP"
    [ -d "$_top" ] || die "expected top-level directory missing: $TOP"

    # Exclusion policy (see header). Assert each path is gone afterwards.
    rm -rf "$_top/kitsunefox" "$_top/.gitignore" "$_top/release"
    [ ! -e "$_top/kitsunefox" ]  || die 'exclusion failed: kitsunefox/'
    [ ! -e "$_top/.gitignore" ]  || die 'exclusion failed: .gitignore'
    [ ! -e "$_top/release" ]     || die 'exclusion failed: release/'

    # Normalize modes so the builder umask cannot leak into the artifact:
    # directories 755, files 644, launcher re-set to 755 (the only file
    # intended to be executable).
    find "$_top" -type d -exec chmod 755 {} +
    find "$_top" -type f -exec chmod 644 {} +
    chmod 755 "$_top/launcher/kitsunefox"

    # Manifest of the final payload: sorted, relative paths, sha256sum -c
    # compatible. Cannot include itself. Repository paths are verified free
    # of spaces/newlines; -d keeps even spaced paths whole on input.
    (
        cd "$_top" &&
        find . -type f ! -name MANIFEST.sha256 | sed 's|^\./||' | sort |
            xargs -d '\n' -r sha256sum
    ) > "$_top/MANIFEST.sha256" || die 'manifest generation failed'
    chmod 644 "$_top/MANIFEST.sha256"

    PAYLOAD_FILES=$(find "$_top" -type f ! -name MANIFEST.sha256 | wc -l | tr -d ' ')
    PAYLOAD_BYTES=$(find "$_top" -type f ! -name MANIFEST.sha256 -printf '%s\n' |
        awk '{ s += $1 } END { print s + 0 }')
    MANIFEST_SHA=$(sha256sum "$_top/MANIFEST.sha256" | cut -d' ' -f1)

    # Deterministic tar: sorted entries, commit-time mtimes, numeric root
    # ownership (empty uname/gname), pinned gnu format; gzip without name
    # or timestamp in its header. tar and gzip run as separate checked
    # steps (no pipes, so set -e cannot mask a mid-pipeline failure).
    tar --format=gnu --sort=name --mtime="@$SDE" \
        --owner=0 --group=0 --numeric-owner \
        -C "$_root" -cf "$_stage/payload.tar" "$TOP" || die 'tar failed'
    gzip -n -9 -c "$_stage/payload.tar" > "$_out" || die 'gzip failed'
}

step 'building twice (reproducibility self-check)'
build_once "$TMP/build-a.tar.gz"
A_MANIFEST_SHA=$MANIFEST_SHA
A_FILES=$PAYLOAD_FILES
build_once "$TMP/build-b.tar.gz"
[ "$A_MANIFEST_SHA" = "$MANIFEST_SHA" ] || die 'internal: manifest diverged between builds'
[ "$A_FILES" = "$PAYLOAD_FILES" ] || die 'internal: file count diverged between builds'
if cmp -s "$TMP/build-a.tar.gz" "$TMP/build-b.tar.gz"; then
    REPRO=true
    step 'repro PASS: two builds are byte-identical'
else
    REPRO=false
    printf 'build.sh: repro FAILURE\n' >&2
    sha256sum "$TMP/build-a.tar.gz" "$TMP/build-b.tar.gz" >&2
    die 'two builds differ; refusing to write output'
fi

# Source presence of each excluded path (for the provenance record).
presence() {
    if git rev-parse --verify -q "${COMMIT}:$1" >/dev/null 2>&1; then
        printf 'true'
    else
        printf 'false'
    fi
}
P_KITSUNEFOX=$(presence kitsunefox)
P_GITIGNORE=$(presence .gitignore)
P_RELEASE=$(presence release)

mkdir -p "$OUT" 2>/dev/null || true
if [ -z "$OUT" ]; then
    OUT="$REPO/dist"
    mkdir -p "$OUT"
fi
OUT=$(cd "$OUT" && pwd) || die "cannot use output directory: $OUT"

cp "$TMP/build-a.tar.gz" "$OUT/$FILE" || die 'cannot write artifact'
(
    cd "$OUT" && sha256sum "$FILE" > "$FILE.sha256"
) || die 'cannot write checksum sidecar'
ARTIFACT_SHA=$(cut -d' ' -f1 < "$OUT/$FILE.sha256")

GIT_V=$(git --version)
TAR_V=$(tar --version | head -n 1)
GZ_V=$(gzip --version | head -n 1)
SHSUM_V=$(sha256sum --version | head -n 1)
BUILD_SHA=$(sha256sum "$REPO/release/build.sh" | cut -d' ' -f1)
VERIFY_SHA=$(sha256sum "$REPO/release/verify.sh" | cut -d' ' -f1)
ORIGIN_URL=$(git remote get-url origin 2>/dev/null || printf '')
UPSTREAM_URL=$(git remote get-url upstream 2>/dev/null || printf '')

# Fork base: only from refs that already exist locally. No fetch is ever
# performed here; absent upstream refs are recorded as such.
FORK_BASE=''
FORK_NOTE='no local upstream refs; run "git fetch upstream" to populate fork-base provenance'
for _r in upstream/HEAD upstream/main upstream/master; do
    if git rev-parse --verify -q "$_r" >/dev/null 2>&1; then
        FORK_BASE=$(git merge-base "$COMMIT" "$_r") || FORK_BASE=''
        if [ -n "$FORK_BASE" ]; then
            FORK_NOTE=''
            break
        fi
    fi
done

BUILT_AT=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# JSON string escaping for controlled dynamic values (sed for \ and ",
# then drop control characters). Values are versions, hashes, and URLs.
jesc() {
    printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' | tr -d '\000-\037'
}

PROV="$OUT/kitsunefox-$VERSION.provenance.json"
{
    printf '{\n'
    printf '  "schema": "kitsunefox-release-provenance/1",\n'
    printf '  "name": "kitsunefox",\n'
    printf '  "version": "%s",\n' "$(jesc "$VERSION")"
    printf '  "artifact": "%s",\n' "$(jesc "$FILE")"
    printf '  "artifact_sha256": "%s",\n' "$ARTIFACT_SHA"
    printf '  "artifact_bytes": %s,\n' "$(wc -c < "$OUT/$FILE" | tr -d ' ')"
    printf '  "source": {\n'
    printf '    "ref": "%s",\n' "$(jesc "$REF")"
    printf '    "commit": "%s",\n' "$COMMIT"
    printf '    "tree": "%s",\n' "$TREE"
    printf '    "commit_date": "%s",\n' "$(jesc "$COMMIT_DATE")"
    printf '    "source_date_epoch": %s,\n' "$SDE"
    printf '    "describe": "%s",\n' "$(jesc "$(git describe --tags --always "$COMMIT")")"
    printf '    "worktree_clean": %s,\n' "$CLEAN"
    printf '    "worktree_dirty_count": %s\n' "$DIRTY_COUNT"
    printf '  },\n'
    printf '  "upstream": {\n'
    printf '    "origin_url": "%s",\n' "$(jesc "$ORIGIN_URL")"
    printf '    "upstream_url": "%s",\n' "$(jesc "$UPSTREAM_URL")"
    printf '    "fork_base_commit": %s,\n' \
        "$([ -n "$FORK_BASE" ] && printf '"%s"' "$FORK_BASE" || printf 'null')"
    printf '    "note": "%s"\n' "$(jesc "$FORK_NOTE")"
    printf '  },\n'
    printf '  "excluded": [\n'
    printf '    {"path": "kitsunefox/", "present_in_source": %s, "reason": "historical snapshot subtree, frozen since the initial commit; stale duplicate (23 themes vs 57 at root)"},\n' "$P_KITSUNEFOX"
    printf '    {"path": ".gitignore", "present_in_source": %s, "reason": "repository maintenance file, not product"},\n' "$P_GITIGNORE"
    printf '    {"path": "release/", "present_in_source": %s, "reason": "build/verify tooling, shipped as separate release assets"}\n' "$P_RELEASE"
    printf '  ],\n'
    printf '  "payload": {\n'
    printf '    "files": %s,\n' "$PAYLOAD_FILES"
    printf '    "bytes": %s,\n' "$PAYLOAD_BYTES"
    printf '    "manifest": "MANIFEST.sha256",\n'
    printf '    "manifest_sha256": "%s"\n' "$MANIFEST_SHA"
    printf '  },\n'
    printf '  "builder": {\n'
    printf '    "script": "release/build.sh",\n'
    printf '    "script_sha256": "%s",\n' "$BUILD_SHA"
    printf '    "verifier_sha256": "%s",\n' "$VERIFY_SHA"
    printf '    "reproducible": %s,\n' "$REPRO"
    printf '    "repro_check": "two consecutive builds byte-compared (cmp); dist written only on match",\n'
    printf '    "toolchain": {\n'
    printf '      "git": "%s",\n' "$(jesc "$GIT_V")"
    printf '      "tar": "%s",\n' "$(jesc "$TAR_V")"
    printf '      "gzip": "%s",\n' "$(jesc "$GZ_V")"
    printf '      "sha256sum": "%s"\n' "$(jesc "$SHSUM_V")"
    printf '    }\n'
    printf '  },\n'
    printf '  "built_at": "%s",\n' "$BUILT_AT"
    printf '  "verification_command": "sh verify.sh %s %s.sha256"\n' \
        "$(jesc "$FILE")" "$(jesc "$FILE")"
    printf '}\n'
} > "$PROV" || die 'cannot write provenance'

cp "$REPO/release/verify.sh" "$OUT/verify.sh" || die 'cannot copy verify.sh'
chmod 755 "$OUT/verify.sh"

BYTES=$(wc -c < "$OUT/$FILE" | tr -d ' ')
step "artifact  $OUT/$FILE ($BYTES bytes)"
step "sha256    $ARTIFACT_SHA"
step "provenance $PROV"
step "repro     PASS (byte-identical double build)"
step "worktree  $CLEAN ($DIRTY_COUNT path(s)); artifact is the COMMITTED tree at $COMMIT"
step 'git state unchanged (no commit, no tag, no push)'
step "next      sh $OUT/verify.sh $OUT/$FILE"
step 'publish   not performed; upload the four dist/ files to a GitHub Release when ready'
