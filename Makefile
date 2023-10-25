# Makefile

.PHONY: doc test coverage-suite

APP_NAME=`awk '/^name:/ {print $$2}' pubspec.yaml`
APP_VERSION=`awk '/^version:/ {print $$2}' pubspec.yaml`

#----------------------------------------------------------------

help:
	@echo "Targets for ${APP_NAME} ${APP_VERSION}:"
	@echo
	@echo "  format     format Dart files (runs \"dart format\")"
	@echo
	@echo "  test            run tests (runs \"dart run test\")"
	@echo "  coverage-suite  updates the files in coverage-suite"
	@echo
	@echo "  doc             generate Dart documentation (runs \"dart doc\")"
	@if uname -s | grep -q -i Darwin ; then \
	  echo "  doc-open        opens generated Dart documentation (macOS only)"; \
	fi
	@echo
	@echo "  pana            check before publishing (runs \"dart run pana\")"
	@echo
	@echo "  clean           deletes generated files"
	@echo

#================================================================
# Development targets

format:
	dart format lib test example

#================================================================
# Testing

test:
	dart run test

coverage-suite:
	@if [ ! -d coverage-suite ]; then \
	  mkdir coverage-suite; \
	fi
	@find coverage-suite -type l -name \*.dart -exec rm {} \;
	@for F in test/*_test.dart; do \
	  ln -s ../$$F coverage-suite/`basename $$F`; \
	done
	@echo "Coverage test programs:"
	@find coverage-suite -type l -name \*.dart -exec echo " - {}" \;
	@echo "Run these with Coverage and add the coverage results into one active suite."

#================================================================
# Documentation

#----------------------------------------------------------------
# Doc
#
# "doc" always deletes the generated documentation directory first
# since any existing files in it are not removed by the "dart doc"
# command.

doc:
	rm -rf doc/api
	dart doc

#----------------------------------------------------------------
# Convenient command to view generated documentation

doc-open:
	@if [ -e doc/api/index.html ]; then \
	  if uname -s | grep -q -i Darwin ; then \
	    open doc/api/index.html; \
	  else \
	    echo "doc-open: cannot run: only works on macOS"; \
	  fi ; \
	else \
	  echo "doc-open: Dart doc not generated (run \"make doc\" first)"; \
	fi

#================================================================
# Publishing

pana:
	dart run pana

#================================================================
# Generation

clean:
	@rm -f -r doc/api
	@if [ -d coverage-suite ]; then \
	  find coverage-suite -type l -name \*.dart -exec rm {} \; ; \
	  rmdir coverage-suite ; \
	fi

#EOF
