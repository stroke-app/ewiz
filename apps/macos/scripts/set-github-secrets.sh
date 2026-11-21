#!/bin/bash
# Superseded by the repo-root secrets script, which also backs the values up so they
# can't be lost (GitHub never shows a secret again once it's set).
exec "$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)/scripts/secrets.sh" push release
