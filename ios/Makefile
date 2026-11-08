SHELL := /bin/bash

.PHONY: project test-kit parity build verify clean

project:
	@command -v xcodegen >/dev/null || { echo 'Install XcodeGen 2.46.0: brew install xcodegen'; exit 1; }
	xcodegen generate --spec project.yml

test-kit:
	swift test --package-path Packages/HueBoardKit

parity:
	cd .. && node scripts/export-ios-contract.cjs
	$(MAKE) test-kit

build: project
	xcodebuild -project HueBoard.xcodeproj -scheme HueBoard -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build

verify: parity build

clean:
	rm -rf HueBoard.xcodeproj Packages/HueBoardKit/.build
