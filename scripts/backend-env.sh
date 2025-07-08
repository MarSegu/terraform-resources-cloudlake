#!/bin/sh
set -euo pipefail

# Determine backend environment based on the branch name
case "$CI_COMMIT_BRANCH" in
  dev|stage|prod)
    echo "$CI_COMMIT_BRANCH"
    ;;
  *)
    echo "dev"
    ;;
esac