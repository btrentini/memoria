SHELL := /bin/sh
.PHONY: build release test probe project ui-test clean
build:
	swift build
release:
	swift build -c release
test:
	swift test
probe:
	swift run MemoriaProbe
project:
	python3 Scripts/generate-project.py
ui-test:
	xcodebuild -project Memoria.xcodeproj -scheme Memoria -configuration Debug -derivedDataPath DerivedData CODE_SIGNING_ALLOWED=NO test
clean:
	swift package clean
