SHELL := /bin/bash

-include device.env
export HUE_BOARD_TEAM_ID
export HUE_BOARD_DEVICE_ID
export HUE_BOARD_BUNDLE_ID
export HUE_BOARD_XCODE_PATH

.PHONY: project test-kit parity build verify clean \
	iphone-preflight iphone-prepare iphone-list iphone-simulator-build \
	iphone-build iphone-install iphone-launch iphone-run iphone-open

project:
	@command -v xcodegen >/dev/null || { echo 'Install XcodeGen 2.46.0: brew install xcodegen'; exit 1; }
	xcodegen generate --spec project.yml

test-kit:
	swift test --package-path Packages/HueBoardKit

parity:
	cd .. && pnpm build && pnpm export:ios-contract
	$(MAKE) test-kit
	cd .. && node --test tests/ios-parity.test.cjs

build: project
	xcodebuild -project HueBoard.xcodeproj -scheme HueBoard -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build

verify: parity build

iphone-preflight:
	bash scripts/device-run.sh preflight

iphone-prepare:
	bash scripts/device-run.sh prepare

iphone-list:
	bash scripts/device-run.sh list

iphone-simulator-build:
	bash scripts/device-run.sh simulator-build

iphone-build:
	bash scripts/device-run.sh device-build

iphone-install:
	bash scripts/device-run.sh device-install

iphone-launch:
	bash scripts/device-run.sh device-launch

iphone-run:
	bash scripts/device-run.sh device-run

iphone-open:
	bash scripts/device-run.sh open

clean:
	rm -rf HueBoard.xcodeproj Packages/HueBoardKit/.build DerivedData
