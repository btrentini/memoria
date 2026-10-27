#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
developer="$(xcode-select -p)"
sdk="$developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk"
mkdir -p build/native-tests
for test in native-smoke native-integration; do
    "$developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/clang" \
        -target arm64-apple-macosx26.0 -isysroot "$sdk" -Wall -Wextra -Werror \
        -I Sources/MemoriaNative/include Sources/MemoriaNative/native.c \
        "Tests/$test.c" -o "build/native-tests/$test"
    "build/native-tests/$test"
done
build/native-tests/native-integration 2
