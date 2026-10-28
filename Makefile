SHELL := /bin/sh
PYTHON ?= python3
.DEFAULT_GOAL := help
.NOTPARALLEL:
.PHONY: help doctor app run verify-app preview-package build release test core-test store-preview store-test probe project ui-test layout-test clean
help:
	@echo "make doctor           Check native build tools and Xcode readiness"
	@echo "make app              Build and bundle build/Memoria.app (development)"
	@echo "make run              Build the app, then open its menu-bar entry"
	@echo "make test             Build and run the core, Store and lifecycle tests"
	@echo "make layout-test      Exercise native window resizing in a GUI session"
	@echo "make verify-app       Verify an existing app bundle"
	@echo "make preview-package  Package an existing app for preview installation"
	@echo "make store-preview    Build the sandboxed App Store preview"
	@echo "make project          Regenerate the checked-in Xcode project"
	@echo "make build/release    Build with Swift Package Manager"
doctor:
	$(PYTHON) Scripts/doctor.py
app: doctor
	$(PYTHON) Scripts/direct-build.py
	$(PYTHON) Scripts/bundle-development.py
	$(PYTHON) Scripts/verify-app.py build/Memoria.app
run: app
	open build/Memoria.app
verify-app:
	$(PYTHON) Scripts/verify-app.py build/Memoria.app
preview-package: verify-app
	$(PYTHON) Scripts/package-preview.py
build:
	swift build
release:
	swift build -c release
test: core-test store-test
core-test: app
	$(PYTHON) Scripts/direct-tests.py
store-preview: doctor
	$(PYTHON) Scripts/build-app-store-preview.py
store-test: store-preview
	$(PYTHON) Scripts/test-app-store.py
	$(PYTHON) Scripts/check-app-store.py --bundle build/store-preview/MemoriaStore.app
probe:
	swift run MemoriaProbe
project:
	$(PYTHON) Scripts/generate-project.py
layout-test: app
	$(PYTHON) Scripts/check-layout.py
ui-test:
	xcodebuild -project Memoria.xcodeproj -scheme Memoria -configuration Debug -derivedDataPath DerivedData CODE_SIGNING_ALLOWED=NO test
clean:
	swift package clean
