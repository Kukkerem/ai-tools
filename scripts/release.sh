#!/usr/bin/env bash
# scripts/release.sh — bump version, commit, tag, and push a new release.
#
# Usage:
#   ./scripts/release.sh <version>   # e.g. ./scripts/release.sh 0.2.0
#
# The script:
#   1. Validates the version argument (semver, no leading v).
#   2. Ensures the working tree is clean.
#   3. Confirms the target branch is main.
#   4. Bumps `version = "..."` in flake.nix.
#   5. Commits with the conventional commit message expected by cliff.toml.
#   6. Creates an annotated tag v<version>.
#   7. Pushes the commit and the tag.

set -euo pipefail

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

die() { echo "error: $*" >&2; exit 1; }
info() { echo "==> $*"; }

# ---------------------------------------------------------------------------
# Validate arguments
# ---------------------------------------------------------------------------

[[ $# -eq 1 ]] || die "usage: $0 <version>  (e.g. $0 0.2.0)"
VERSION="$1"

# Strip optional leading 'v' so callers can pass either form.
VERSION="${VERSION#v}"

# Require semver-ish: MAJOR.MINOR.PATCH (digits only).
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] \
  || die "version must be MAJOR.MINOR.PATCH (e.g. 1.2.3), got: $VERSION"

TAG="v${VERSION}"

# ---------------------------------------------------------------------------
# Pre-flight checks
# ---------------------------------------------------------------------------

# Must be run from the repo root.
REPO_ROOT="$(git -C "$(dirname "$0")" rev-parse --show-toplevel)"
cd "$REPO_ROOT"

# Working tree must be clean.
if ! git diff --quiet || ! git diff --cached --quiet; then
  die "working tree is dirty — commit or stash changes first"
fi

# Must be on main.
BRANCH="$(git rev-parse --abbrev-ref HEAD)"
if [[ "$BRANCH" != "main" ]]; then
  die "must release from the 'main' branch (currently on '$BRANCH')"
fi

# Tag must not already exist.
if git rev-parse "$TAG" &>/dev/null; then
  die "tag $TAG already exists"
fi

# flake.nix must exist and contain a version field.
grep -q 'version = "' flake.nix \
  || die "flake.nix does not contain a 'version = \"...\"' field"

# ---------------------------------------------------------------------------
# Bump version in flake.nix
# ---------------------------------------------------------------------------

OLD_VERSION="$(grep 'version = "' flake.nix | head -1 | sed 's/.*version = "\(.*\)".*/\1/')"
info "bumping version: $OLD_VERSION → $VERSION"

sed -i "s/version = \"${OLD_VERSION}\"/version = \"${VERSION}\"/" flake.nix

# Verify exactly one line changed.
CHANGED="$(git diff flake.nix | grep -c '^[+-].*version = "' || true)"
if [[ "$CHANGED" -ne 2 ]]; then
  git checkout flake.nix
  die "expected exactly one version line to change in flake.nix (got $CHANGED); reverting"
fi

# ---------------------------------------------------------------------------
# Commit + tag
# ---------------------------------------------------------------------------

git add flake.nix
git commit -m "chore: bump flake version to ${TAG}"

info "creating annotated tag $TAG"
git tag -a "$TAG" -m "Release ${TAG}"

# ---------------------------------------------------------------------------
# Push
# ---------------------------------------------------------------------------

info "pushing commit and tag to origin"
git push origin main
git push origin "$TAG"

info "done — $TAG pushed. The GitHub Actions release workflow will create the GitHub release."
