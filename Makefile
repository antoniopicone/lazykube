# LazyKube - Installation Makefile
# This Makefile handles system-wide installation of lazykube

PREFIX ?= /usr/local
BINDIR = $(PREFIX)/bin
LIBDIR = $(PREFIX)/lib/lazykube
SHAREDIR = $(PREFIX)/share/lazykube
MANDIR = $(PREFIX)/share/man

# Version
VERSION = 1.0.0

.PHONY: all install uninstall help clean test

all: help

help:
	@echo "LazyKube Installation Makefile"
	@echo ""
	@echo "Available targets:"
	@echo "  install      Install lazykube to $(PREFIX)"
	@echo "  uninstall    Remove lazykube from $(PREFIX)"
	@echo "  clean        Clean build artifacts"
	@echo "  test         Run basic tests"
	@echo ""
	@echo "Installation directories:"
	@echo "  Binary:      $(BINDIR)/lazykube"
	@echo "  Library:     $(LIBDIR)/"
	@echo "  Share:       $(SHAREDIR)/"
	@echo "  Man pages:   $(MANDIR)/man{1,7}/"
	@echo ""
	@echo "To install with a different prefix:"
	@echo "  make install PREFIX=/opt/local"
	@echo ""
	@echo "Or use the lazykube command directly:"
	@echo "  ./bin/lazykube install"
	@echo ""

install:
	@echo "Installing LazyKube $(VERSION)..."
	@echo "Prefix: $(PREFIX)"
	@echo ""

	# Create directories
	@echo "Creating directories..."
	@install -d $(BINDIR)
	@install -d $(LIBDIR)
	@install -d $(SHAREDIR)
	@install -d $(MANDIR)/man1
	@install -d $(MANDIR)/man7

	# Install binary
	@echo "Installing lazykube binary..."
	@install -m 0755 bin/lazykube $(BINDIR)/lazykube

	# Install library files
	@echo "Installing library files..."
	@cp -r lib/* $(LIBDIR)/
	@chmod -R u=rwX,go=rX $(LIBDIR)
	@chmod +rx $(LIBDIR)/scripts/*.sh

	# Install shared files
	@echo "Installing shared files..."
	@cp -r share/* $(SHAREDIR)/
	@chmod -R u=rwX,go=rX $(SHAREDIR)

	# Install man pages
	@echo "Installing man pages..."
	@install -m 0644 man/man1/*.1 $(MANDIR)/man1/ 2>/dev/null || true
	@install -m 0644 man/man7/*.7 $(MANDIR)/man7/ 2>/dev/null || true

	# Update man database
	@if command -v mandb >/dev/null 2>&1; then \
		echo "Updating man database..."; \
		mandb -q 2>/dev/null || true; \
	elif command -v makewhatis >/dev/null 2>&1; then \
		echo "Updating man database..."; \
		makewhatis $(MANDIR) 2>/dev/null || true; \
	fi

	@echo ""
	@echo "✓ Installation completed!"
	@echo ""
	@echo "Next steps:"
	@echo "  1. Run: lazykube configure"
	@echo "  2. Run: lazykube cluster-install"
	@echo "  3. Run: man lazykube"
	@echo ""

uninstall:
	@echo "Uninstalling LazyKube..."
	@echo "Prefix: $(PREFIX)"
	@echo ""

	# Remove files
	@echo "Removing files..."
	@rm -f $(BINDIR)/lazykube
	@rm -rf $(LIBDIR)
	@rm -rf $(SHAREDIR)
	@rm -f $(MANDIR)/man1/lazykube.1
	@rm -f $(MANDIR)/man7/lazykube-*.7

	# Update man database
	@if command -v mandb >/dev/null 2>&1; then \
		echo "Updating man database..."; \
		mandb -q 2>/dev/null || true; \
	elif command -v makewhatis >/dev/null 2>&1; then \
		echo "Updating man database..."; \
		makewhatis $(MANDIR) 2>/dev/null || true; \
	fi

	@echo ""
	@echo "✓ Uninstall completed!"
	@echo ""
	@echo "User configuration in ~/.lazykube/ has been preserved."
	@echo "To remove it: rm -rf ~/.lazykube"
	@echo ""

clean:
	@echo "Cleaning build artifacts..."
	@find . -name "*.retry" -delete
	@find . -name "*.bak" -delete
	@find . -name ".DS_Store" -delete
	@echo "✓ Cleanup completed"

test:
	@echo "Running basic tests..."
	@echo "Checking script syntax..."
	@bash -n bin/lazykube
	@bash -n lib/scripts/configure-cluster.sh
	@echo "✓ All tests passed"
