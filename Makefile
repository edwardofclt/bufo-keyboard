.PHONY: all generate fetch clean help

all: generate

help:
	@echo "Bufo Keyboard build helpers"
	@echo ""
	@echo "  make generate   Generate BufoKeyboard.xcodeproj from project.yml (requires xcodegen)"
	@echo "  make fetch      Re-fetch bufo assets from https://github.com/tfritzy/bufo.fun"
	@echo "  make open       Generate the project and open it in Xcode"
	@echo "  make clean      Remove generated Xcode project"

generate:
	@command -v xcodegen >/dev/null 2>&1 || { \
	  echo "xcodegen not found. Install with: brew install xcodegen"; exit 1; }
	xcodegen generate

open: generate
	open BufoKeyboard.xcodeproj

fetch:
	./scripts/fetch-bufos.sh

clean:
	rm -rf BufoKeyboard.xcodeproj build DerivedData
