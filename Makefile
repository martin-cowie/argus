SWIFT_FLAGS := $(shell scripts/swift-flags.sh)

.PHONY: build run test app clean

build:
	swift build $(SWIFT_FLAGS)

run:
	swift run $(SWIFT_FLAGS) Argus

test:
	swift test $(SWIFT_FLAGS)

app:
	./scripts/bundle.sh

clean:
	rm -rf .build dist
