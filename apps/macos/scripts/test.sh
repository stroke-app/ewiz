#!/bin/bash
# Runs the Swift test suite + benchmarks.
# Usage: ./scripts/test.sh [extra swift test args, e.g. --filter Caffeine]
#
# With only the Command Line Tools installed, swift-testing's Testing.framework
# isn't on the default search path, so we point the build at it and bake in the
# rpaths. Full Xcode (incl. GitHub CI runners) needs none of this.
set -euo pipefail

DEV="$(xcode-select -p)"
if [[ "$DEV" == *CommandLineTools* ]]; then
    FW="$DEV/Library/Developer/Frameworks"
    LIB="$DEV/Library/Developer/usr/lib"
    exec swift test \
        -Xswiftc -F"$FW" \
        -Xlinker -F"$FW" \
        -Xlinker -rpath -Xlinker "$FW" \
        -Xlinker -rpath -Xlinker "$LIB" "$@"
else
    exec swift test "$@"
fi
