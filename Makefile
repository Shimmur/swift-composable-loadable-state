default: test

test-swift:
	swift test
	swift test -c release
