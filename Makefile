# Makefile

# This Makefile should not need to be modified. All it depends upon is
# the application "name" and "version" from the pubspec.yaml file.

FILES_TO_INSTALL=bin lib pubspec.yaml pubspec.lock packages
FILES_IN_BUILD=bin lib etc pubspec.yaml pubspec.lock README.md Makefile

.PHONY: build coverage-suite

APP_NAME=`awk '/^name:/ {print $$2}' pubspec.yaml`
APP_VERSION=`awk '/^version:/ {print $$2}' pubspec.yaml`

INSTDIR=/opt/${APP_NAME}
CONFIGDIR=/etc/opt/${APP_NAME}
INIT_SCRIPT="/etc/init.d/${APP_NAME}"
LOGDIR=/var/opt/${APP_NAME}

DARTDIR=/usr/lib/dart

CHKCONFIG=chkconfig

USER=`id -u`
GROUP=`id -g`

# For Ubuntu:
#   run "sudo apt-get install sysv-rc-conf" and uncomment the following line
# CHKCONFIG=sysv-rc-conf

help:
	@echo "Targets for ${APP_NAME} (version ${APP_VERSION}):"
	@if [ -e "test" ]; then \
	  echo "Development targets:"; \
	  echo "  dartfmt     - format Dart files"; \
	  echo "  dartdoc     - generate API documentation"; \
	  echo "  dartdocview - view generated API documentation"; \
	  echo "  build       - creates tar distributable"; \
	  echo "  clean       - deletes build directory"; \
	  echo "Deployment targets:"; \
	fi
	@echo "  coverage-suite - updates the files in coverage-suite"
	@echo "  install        - install service and init.d script"
	@echo "  uninstall      - uninstalls service and init.d script"
	@echo "  purge          - uninstall and deletes config and logs"
	@echo
	@echo "Deployment settings: (change by editing the Makefile)"
	@echo "  Installation directory: ${INSTDIR}"
	@echo "  Config directory: ${CONFIGDIR}"
	@echo "  Log directory: ${LOGDIR}"
	@echo "  Dart directory: ${DARTDIR}"

# Deployment targets

install:
	@if [ ! -d "${DARTDIR}" ]; then \
	  echo "Error: DARTDIR not found: ${DARTDIR}" >&2 ; \
	  exit 1; \
	fi
	@if [ -d "${INSTDIR}" ]; then \
	  echo "Error: INSTDIR already exists: ${INSTDIR}" >&2 ; \
	  exit 1; \
	fi
	@if [ -f "${INIT_SCRIPT}" ]; then \
	  echo "Error: init script already exists: ${INIT_SCRIPT}" >&2 ; \
	  exit 1; \
	fi
	@mkdir -p "${LOGDIR}"
	@mkdir "${INSTDIR}"
	@cp -a ${FILES_TO_INSTALL} "${INSTDIR}"
	@chown -R ${USER}:${GROUP} "${INSTDIR}" "${LOGDIR}"
	@if [ ! -d "${CONFIGDIR}" ]; then \
	  mkdir -p "${CONFIGDIR}" && \
	  cp etc/${APP_NAME}.conf "${CONFIGDIR}/${APP_NAME}.conf" && \
	  chown -R ${USER}:${GROUP} "${CONFIGDIR}" ; \
	fi
	@awk "{print} /^DARTDIR=/ { print \"DARTDIR=${DARTDIR}\" } /^CONFIG_FILE=/ { print \"CONFIG_FILE=${CONFIGDIR}/${APP_NAME}.conf\" }" \
	  etc/init-script.sh > "${INIT_SCRIPT}"
	@chmod 755 "${INIT_SCRIPT}"
	@cd "${INSTDIR}" && "${DARTDIR}/bin/pub" get
	@${CHKCONFIG} "${APP_NAME}" on

uninstall:
	@if [ -f "${LOGDIR}/${APP_NAME}.pid" ]; then \
	  echo "Error: please run \"service ${APP_NAME} stop\" first"; exit 1; fi
	@if [ -f "${INIT_SCRIPT}" ]; \
	  then ${CHKCONFIG} "${APP_NAME}" off; fi
	@rm -f "${INIT_SCRIPT}"
	@rm -f -r "${INSTDIR}"

purge: uninstall
	@rm -f -r "${LOGDIR}"
	@rm -f "${CONFIGDIR}/${APP_NAME}.conf"
	@rmdir "${CONFIGDIR}"

# Development targets

dartfmt:
	@dartfmt -w lib test example | grep -v ^Unchanged

dartdoc:
	@dartdoc

dartdocview:
	@open doc/api/index.html

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

build:
	@rm -rf "build/${APP_NAME}-${APP_VERSION}"
	@mkdir -p "build/${APP_NAME}-${APP_VERSION}"
	@cp -a ${FILES_IN_BUILD} "build/${APP_NAME}-${APP_VERSION}"
	@find "build/${APP_NAME}-${APP_VERSION}" -name \*~ -exec rm {} \;
	@mkdir "build/${APP_NAME}-${APP_VERSION}/packages"
	@tar -c -z -f "build/${APP_NAME}-${APP_VERSION}.tar.gz" \
	   -C build "${APP_NAME}-${APP_VERSION}"
	@rm -rf "build/${APP_NAME}-${APP_VERSION}"
	@echo "Built: build/${APP_NAME}-${APP_VERSION}.tar.gz"

clean:
	@rm -f -r .pub build doc/api *~
	@if [ -d coverage-suite ]; then \
	  find coverage-suite -type l -name \*.dart -exec rm {} \; ; \
	  rmdir coverage-suite ; \
	fi

#EOF
