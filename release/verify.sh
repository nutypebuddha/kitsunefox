#!/bin/sh
# kitsunefox clean-machine release verifier.
#
# Verifies a downloaded release artifact on any Linux machine with a POSIX
# shell and coreutils. Requires NO git, NO python, NO network.
#
# usage:
#   sh verify.sh kitsunefox-<version>.tar.gz [checksum-file-or-sha256]
#
# Checks, in order (fail-closed; every failure increments a counter and the
# script exits 1 if any check failed):
#
#   pre-extract
#     1  external checksum: explicit argument and/or <tarball>.sha256
#        sidecar and/or a matching PROVENANCE-*.json beside the tarball;
#        at least one must be present or the run is UNANCHORED (warning)
#     2  tarball lists successfully (gzip integrity)
#     3  entry scan: no absolute paths, no '..' components, exactly one
#        top-level directory, and it is named kitsunefox-*
#   post-extract (to a private temp dir, removed on exit)
#     4  MANIFEST.sha256 present at the root
#     5  sha256sum -c MANIFEST.sha256: every file matches
#     6  set equality: files on disk == manifest entries (no smuggled
#        extras, no missing files)
#     7  required product files present: user.js, userContent.css,
#        README.md, LICENSE, launcher/kitsunefox, launcher/kitsunefox.desktop
#     8  user.js actually contains user_pref(...) entries
#     9  launcher: executable, #!/bin/sh shebang, passes sh -n
#    10  desktop entry: Type=Application, Name=, Exec=
#    11  repository-only files absent: nested kitsunefox/, .git/, release/,
#        .gitignore; no symlinks; no files executable except the launcher
#    12  provenance cross-check (when provenance beside the tarball):
#        artifact_sha256 and payload file count agree with observation
#
# The summary distinguishes EXTERNALLY ANCHORED (a checksum source was
# present and matched) from structure-only runs. Checksums on the same
# download page protect against corruption and mixed-up assets, not against
# a hostile publisher; see release/README.md for the trust model.

set -eu
export LC_ALL=C

checks=0
failed=0

ok()   { checks=$((checks + 1)); printf '[ok]   %s\n' "$*"; }
fail() { checks=$((checks + 1)); failed=$((failed + 1)); printf '[FAIL] %s\n' "$*"; }
warn() { printf '[warn] %s\n' "$*"; }
info() { printf '[info] %s\n' "$*"; }

usage() {
    cat <<'EOF'
usage: sh verify.sh kitsunefox-<version>.tar.gz [checksum-file-or-sha256]

Verifies a kitsunefox release archive: external checksum (when available),
archive entry safety, per-file manifest integrity, and runnability layout.
Needs only sh, tar, gzip, and coreutils. No git, no network.
EOF
}

case ${1:-} in
    ''|-h|--help) usage; exit 2 ;;
esac

TARBALL=$1
EXPLICIT=${2:-}

for t in tar gzip sha256sum find sort sed awk cmp mktemp cut wc tr head grep; do
    command -v "$t" >/dev/null 2>&1 || {
        printf '[FAIL] missing required tool: %s\n' "$t" >&2
        exit 1
    }
done

[ -f "$TARBALL" ] || { printf '[FAIL] not a file: %s\n' "$TARBALL" >&2; exit 2; }
case $TARBALL in
    *.tar.gz) ;;
    *) printf '[FAIL] expected a *.tar.gz file: %s\n' "$TARBALL" >&2; exit 2 ;;
esac

DIR=$(dirname "$TARBALL")
BASE=$(basename "$TARBALL")
TOP=${BASE%.tar.gz}

TMP=$(mktemp -d "${TMPDIR:-/tmp}/kitsunefox-verify.XXXXXX") ||
    { printf '[FAIL] mktemp failed\n' >&2; exit 1; }
cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT
trap 'cleanup; exit 130' INT
trap 'cleanup; exit 143' TERM

OBSERVED=$(sha256sum "$TARBALL" | cut -d' ' -f1)
norm_hash() { printf '%s' "$1" | tr 'A-F' 'a-f'; }
check_expected() {
    # $1 = expected hex, $2 = human source description
    SOURCES=$((SOURCES + 1))
    _want=$(norm_hash "$1")
    case $_want in
        *[!0-9a-f]*|'')
            fail "checksum source $2 is not a sha256 hex digest"
            return
            ;;
    esac
    if [ "${#_want}" -ne 64 ]; then
        fail "checksum source $2 is not 64 hex characters"
        return
    fi
    if [ "$_want" = "$OBSERVED" ]; then
        ok "external checksum matches ($2)"
        ANCHORED=yes
    else
        fail "external checksum MISMATCH ($2): want $_want, got $OBSERVED"
    fi
}

ANCHORED=no
SOURCES=0

# --- 1: external checksum sources ------------------------------------------
if [ -n "$EXPLICIT" ]; then
    if [ -f "$EXPLICIT" ]; then
        _h=$(head -n 1 "$EXPLICIT" | cut -d' ' -f1)
        check_expected "$_h" "argument file $EXPLICIT"
    else
        check_expected "$EXPLICIT" 'argument'
    fi
fi
if [ -f "$TARBALL.sha256" ]; then
    if [ "$EXPLICIT" = "$TARBALL.sha256" ]; then
        ok 'sidecar <tarball>.sha256 present (already checked via argument)'
    else
        _h=$(head -n 1 "$TARBALL.sha256" | cut -d' ' -f1)
        check_expected "$_h" 'sidecar <tarball>.sha256'
    fi
fi

# A provenance file that BELONGS to this tarball also counts as an anchor.
PROV=''
for _p in "$DIR"/kitsunefox-*.provenance.json; do
    [ -f "$_p" ] || continue
    _pa=$(sed -n 's/.*"artifact": "\([^"]*\)".*/\1/p' "$_p" | head -n 1)
    [ "$_pa" = "$BASE" ] || continue
    PROV=$_p
    break
done
if [ -n "$PROV" ]; then
    _h=$(sed -n 's/.*"artifact_sha256": "\([0-9a-f]*\)".*/\1/p' "$PROV" | head -n 1)
    if [ -z "$_h" ]; then
        fail "provenance $(basename "$PROV") has no artifact_sha256 field"
    else
        check_expected "$_h" "provenance $(basename "$PROV")"
    fi
else
    info 'no matching provenance JSON beside the tarball (optional)'
fi
if [ "$ANCHORED" = no ]; then
    if [ "$SOURCES" -eq 0 ]; then
        warn 'external checksum: NOT PROVIDED - structure and manifest will be verified, authenticity is NOT anchored'
    else
        warn 'external checksum: present but NONE matched - authenticity is NOT anchored'
    fi
fi

# --- 2: lists successfully ---------------------------------------------------
if ! tar -tzf "$TARBALL" > "$TMP/listing" 2> "$TMP/list.err"; then
    fail 'tarball does not list (corrupt or not a gzip tar)'
    sed 's/^/       /' "$TMP/list.err" | head -n 5
    printf '\nverify: %s check(s), %s failed\n' "$checks" "$failed"
    printf 'verify: FAIL\n'
    exit 1
fi
ok 'tarball lists successfully'

# --- 3: entry scan ----------------------------------------------------------
scan_bad=0
seen_top=''
while IFS= read -r e; do
    [ -n "$e" ] || continue
    case $e in
        /*)
            fail "absolute path in archive: $e"
            scan_bad=1
            continue
            ;;
    esac
    case "/$e/" in
        */../*)
            fail "path-traversal component in archive: $e"
            scan_bad=1
            continue
            ;;
    esac
    _first=${e%%/*}
    if [ -z "$seen_top" ]; then
        seen_top=$_first
    elif [ "$_first" != "$seen_top" ]; then
        fail "multiple top-level entries: '$seen_top' and '$_first'"
        scan_bad=1
    fi
done < "$TMP/listing"
if [ "$scan_bad" -eq 0 ]; then
    ok 'entry scan: no absolute paths, no .. components, single top-level directory'
fi
case $seen_top in
    kitsunefox-*) ok "top-level directory name: $seen_top" ;;
    *)            fail "top-level directory not named kitsunefox-*: '$seen_top'" ;;
esac
[ "$seen_top" = "$TOP" ] &&
    ok 'top-level directory matches tarball file name' ||
    fail "top-level directory '$seen_top' does not match file name '$TOP'"

# --- extract ----------------------------------------------------------------
if ! tar -xzf "$TARBALL" -C "$TMP" 2> "$TMP/ex.err"; then
    fail 'extraction failed'
    sed 's/^/       /' "$TMP/ex.err" | head -n 5
    printf '\nverify: %s check(s), %s failed\n' "$checks" "$failed"
    printf 'verify: FAIL\n'
    exit 1
fi
ROOT="$TMP/$seen_top"
[ -d "$ROOT" ] || { fail "extracted root missing: $seen_top"; printf 'verify: FAIL\n'; exit 1; }
ok "extracted to private temp dir ($seen_top/)"

# --- 4: manifest present ----------------------------------------------------
if [ -f "$ROOT/MANIFEST.sha256" ]; then
    ok 'MANIFEST.sha256 present'
else
    fail 'MANIFEST.sha256 missing at artifact root'
fi

# --- 5: manifest hash verification ------------------------------------------
if [ -f "$ROOT/MANIFEST.sha256" ]; then
    if _out=$(cd "$ROOT" && sha256sum -c MANIFEST.sha256 2>&1); then
        _n=$(printf '%s\n' "$_out" | grep -c ': OK$' || true)
        ok "manifest: all $_n file hashes match"
    else
        fail 'manifest: one or more file hashes do NOT match'
        printf '%s\n' "$_out" | grep -E 'FAILED|No such|WARNING' | head -n 10 | sed 's/^/       /' || true
    fi

    # --- 6: set equality ----------------------------------------------------
    (cd "$ROOT" && find . -type f ! -name MANIFEST.sha256 | sed 's|^\./||' | sort) > "$TMP/on_disk"
    sed 's/^[0-9a-f]\{64\}  //' "$ROOT/MANIFEST.sha256" | sort > "$TMP/in_manifest"
    if cmp -s "$TMP/on_disk" "$TMP/in_manifest"; then
        ok 'set equality: files on disk == manifest entries'
    else
        fail 'set mismatch between extracted files and manifest'
        comm -3 "$TMP/on_disk" "$TMP/in_manifest" | head -n 10 | sed 's/^/       /' || true
    fi
fi

# --- 7: required product files ---------------------------------------------
for f in user.js userContent.css README.md LICENSE \
         launcher/kitsunefox launcher/kitsunefox.desktop; do
    if [ -s "$ROOT/$f" ]; then
        ok "present and non-empty: $f"
    elif [ -e "$ROOT/$f" ]; then
        fail "present but EMPTY: $f"
    else
        fail "missing required file: $f"
    fi
done

# --- 8: user.js has real preferences ---------------------------------------
if [ -f "$ROOT/user.js" ]; then
    if grep -q 'user_pref(' "$ROOT/user.js"; then
        _n=$(grep -c 'user_pref(' "$ROOT/user.js" || true)
        ok "user.js contains $_n user_pref(...) line(s)"
    else
        fail 'user.js contains no user_pref(...) entries'
    fi
fi

# --- 9: launcher runnability ------------------------------------------------
if [ -f "$ROOT/launcher/kitsunefox" ]; then
    [ -x "$ROOT/launcher/kitsunefox" ] &&
        ok 'launcher is executable' ||
        fail 'launcher is NOT executable'
    head -n 1 "$ROOT/launcher/kitsunefox" | grep -q '^#!/bin/sh' &&
        ok 'launcher shebang is #!/bin/sh' ||
        fail 'launcher shebang is not #!/bin/sh'
    if sh -n "$ROOT/launcher/kitsunefox" 2> "$TMP/shn.err"; then
        ok 'launcher passes sh -n (same check the push gate registers)'
    else
        fail 'launcher fails sh -n'
        sed 's/^/       /' "$TMP/shn.err" | head -n 5
    fi
fi

# --- 10: desktop entry ------------------------------------------------------
if [ -f "$ROOT/launcher/kitsunefox.desktop" ]; then
    grep -q '^Type=Application' "$ROOT/launcher/kitsunefox.desktop" &&
        ok 'desktop entry: Type=Application' || fail 'desktop entry: Type=Application missing'
    grep -q '^Name=' "$ROOT/launcher/kitsunefox.desktop" &&
        ok 'desktop entry: Name=' || fail 'desktop entry: Name= missing'
    grep -q '^Exec=' "$ROOT/launcher/kitsunefox.desktop" &&
        ok 'desktop entry: Exec=' || fail 'desktop entry: Exec= missing'
fi

# --- 11: repository-only files absent ---------------------------------------
[ ! -e "$ROOT/kitsunefox" ] &&
    ok 'excluded subtree absent: kitsunefox/' || fail 'excluded subtree PRESENT: kitsunefox/'
[ ! -e "$ROOT/.gitignore" ] &&
    ok 'excluded file absent: .gitignore' || fail 'excluded file PRESENT: .gitignore'
[ ! -e "$ROOT/release" ] &&
    ok 'excluded directory absent: release/' || fail 'excluded directory PRESENT: release/'
[ ! -e "$ROOT/.git" ] &&
    ok 'no .git in artifact' || fail '.git present in artifact'
if [ -n "$(find "$ROOT" -type l | head -n 1)" ]; then
    fail 'artifact contains symlinks (expected plain files only)'
else
    ok 'no symlinks in artifact'
fi
_extra_exec=$(find "$ROOT" -type f -perm /111 ! -path "$ROOT/launcher/kitsunefox" | head -n 1)
if [ -z "$_extra_exec" ]; then
    ok 'only launcher/kitsunefox is executable'
else
    fail "unexpected executable file: ${_extra_exec#"$ROOT"/}"
fi

# --- 12: provenance cross-check (file count; hash checked pre-extract) ------
if [ -n "$PROV" ]; then
    _pc=$(sed -n 's/.*"files": \([0-9]*\).*/\1/p' "$PROV" | head -n 1)
    _obs=$(wc -l < "$TMP/on_disk" 2>/dev/null | tr -d ' ' || printf '0')
    if [ -z "$_pc" ]; then
        fail 'provenance has no payload file count'
    elif [ "$_pc" = "$_obs" ]; then
        ok "provenance payload file count matches observation ($_obs)"
    else
        fail "provenance file count $_pc != observed $_obs"
    fi
fi

# --- summary -----------------------------------------------------------------
_n_themes=$(find "$ROOT" -mindepth 2 -maxdepth 2 -name userChrome.css | wc -l | tr -d ' ')
_n_catp=$(find "$ROOT" -mindepth 1 -maxdepth 1 -name 'userChrome-*.css' | wc -l | tr -d ' ')
_n_files=$(wc -l < "$TMP/on_disk" 2>/dev/null | tr -d ' ' || printf '?')
info "contents: $_n_themes theme dirs, $_n_catp Catppuccin root sheets, $_n_files payload files"
info "artifact: $BASE"
info "sha256:   $OBSERVED"
if [ "$ANCHORED" = yes ]; then
    info 'integrity: EXTERNALLY ANCHORED (checksum source present and matching)'
elif [ "$SOURCES" -eq 0 ]; then
    info 'integrity: structure-only (no external checksum source found)'
else
    info 'integrity: NOT ANCHORED (checksum source present but none matched)'
fi

printf '\nverify: %s check(s), %s failed\n' "$checks" "$failed"
if [ "$failed" -eq 0 ]; then
    printf 'verify: PASS\n'
    exit 0
else
    printf 'verify: FAIL\n'
    exit 1
fi
