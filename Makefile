SWIFT_FLAGS := $(shell scripts/swift-flags.sh)

.PHONY: build run test app icon clean

build:
	swift build $(SWIFT_FLAGS)

run:
	swift run $(SWIFT_FLAGS) Argus

test:
	swift test $(SWIFT_FLAGS)

app:
	./scripts/bundle.sh

# Regenerates Resources/AppIcon.png from the SVG; needs rsvg-convert (brew install librsvg).
# Apple's icon grid centres 824px of artwork on a 1024px canvas.
icon:
	rsvg-convert --width 824 --height 824 --page-width 1024 --page-height 1024 --left 100 --top 100 \
		--output Resources/AppIcon.png Resources/AppIcon.svg

clean:
	rm -rf .build dist
