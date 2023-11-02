# Makefile

.PHONY: doc test coverage

APP_NAME=`awk '/^name:/ {print $$2}' pubspec.yaml`
APP_VERSION=`awk '/^version:/ {print $$2}' pubspec.yaml`

#----------------------------------------------------------------

help:
	@echo "Targets for ${APP_NAME} ${APP_VERSION}:"
	@echo
	@echo "  format          format Dart files (runs \"dart format\")"
	@echo
	@echo "  test            run tests (runs \"dart run test\")"
	@echo "  coverage        generate coverage report from the tests"
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

# genhtml is required to convert the coverage data into a HTML report.
# For some reason, HomeBrew installs it but does not create a symbolic link
# in the /opt/homebrew/bin directory. So the executable must be accessed
# by a full path. Of course, this depends on where HomeBrew is installed.

GENHTML=${HOMEBREW_CELLAR}/lcov/2.0/bin/genhtml

coverage:
	dart run coverage:test_with_coverage -f -b
	@echo
	@if [ ! -x "${GENHTML}" ]; then \
	  echo "Error: executable not found: ${GENHTML}" >&2 ; \
	  echo "  genhtml is from lcov <https://github.com/linux-test-project/lcov>" >&2 ; \
	  echo "  If you have HomeBrew, it can be installed with \"brew install lcov\"." >&2 ; \
	  echo ; \
	  exit 3 ; \
	fi
	"${GENHTML}" coverage/lcov.info -o coverage/html
	@echo '--------'
	@echo "View coverage report by opening: coverage/html/index.html"

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
