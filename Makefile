APP = Clarion.app
BINARY = $(APP)/Contents/MacOS/clarion
SOURCES = Sources/main.swift Sources/Notifier.swift Sources/PayloadParser.swift

.PHONY: all build sign install clean

all: build sign

build: $(BINARY)

$(BINARY): $(SOURCES)
	@mkdir -p $(APP)/Contents/MacOS
	@mkdir -p $(APP)/Contents/Resources
	swiftc $(SOURCES) -o $(BINARY)

sign: $(BINARY)
	codesign --force --deep --sign - $(APP)

install: all
	cp -r $(APP) /Applications/$(APP)
	@echo "Installed to /Applications/$(APP)"

clean:
	rm -rf $(APP)/Contents/MacOS/clarion
