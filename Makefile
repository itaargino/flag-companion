XCODEBUILD_FLAGS ?=

.PHONY: test test-package test-app

test: test-package test-app

test-package:
	swift test --package-path FlagCompanionKit

test-app:
	xcodebuild test \
		-project FlagCompanion/FlagCompanion.xcodeproj \
		-scheme FlagCompanion \
		-destination 'platform=macOS' \
		-quiet \
		$(XCODEBUILD_FLAGS)
