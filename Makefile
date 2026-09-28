# The Command Line Tools ship the Swift Testing macro plugin in a directory the compiler
# does not search by default; Xcode does not need this.
CLT_TESTING_PLUGINS := /Library/Developer/CommandLineTools/usr/lib/swift/host/plugins/testing
TEST_FLAGS := $(if $(wildcard $(CLT_TESTING_PLUGINS)),-Xswiftc -plugin-path -Xswiftc $(CLT_TESTING_PLUGINS))

.PHONY: build run test app clean

build:
	swift build

run:
	swift run Argus

test:
	swift test $(TEST_FLAGS)

app:
	./scripts/bundle.sh

clean:
	rm -rf .build dist
