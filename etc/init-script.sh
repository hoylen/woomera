#!/bin/sh
#
# chkconfig: 2345 08 92

APP_NAME=woomera

INST_DIR=/opt/${APP_NAME}
CONFIG_FILE=/etc/opt/${APP_NAME}/${APP_NAME}.conf
VAR_DIR=/var/opt/${APP_NAME}
MAIN_DART=main.dart

DARTDIR="/usr/lib/dart"
DART="${DARTDIR}/bin/dart"

# Development (set RUN_FROM_DIR to project dir to run without installing)
if [ -n "$RUN_FROM_DIR" ]; then
  INST_DIR="$RUN_FROM_DIR"
  VAR_DIR="$RUN_FROM_DIR/tmp/log"
  DART=
fi

#----------------

PROG=`basename $0`

PID_FILE="${VAR_DIR}/${APP_NAME}.pid"
LOG_FILE="${VAR_DIR}/${APP_NAME}.log"
AUDIT_FILE="${VAR_DIR}/${APP_NAME}.audit"

start() {
  # Need Dart program

  if [ -n "$DART" ]; then
    if [ ! -x "$DART" ]; then
      # Explicit dart executable supplied and it is wrong
      echo "$PROG: error: dart not found: $DART" >&2
      return 1
    fi
  else
    # No explicit dart executable: try to find dart in PATH
    DART=`which dart`
    if [ $? -ne 0 ]; then
      echo "$PROG: error: dart not found" >&2
      return 1
    fi
  fi

  # Need data and log directories to be writable by this user

  if [ ! -w "$VAR_DIR" ]; then
    echo "$PROG: error: cannot write to directory: $VAR_DIR" >&2
    return 1
  fi

  # Check for already running process

  if [ -f "$PID_FILE" ]; then
    PID=`cat "$PID_FILE"`
    ps -p "$PID" >/dev/null
    if [ $? -eq 0 ]; then
      # Process still running
      echo "$PROG: error: already running" >&2
      return 1
    else
      # Process not running: stale PID file
      rm "$PID_FILE"
    fi
  fi

  # Start server

  "$DART" "$INST_DIR/bin/$MAIN_DART" \
    --config "${CONFIG_FILE}" \
    --audit "${AUDIT_FILE}" \
    >> "$LOG_FILE" 2>&1 &

  PID=$!
  echo $PID > "$PID_FILE"

  # Check for early death

  sleep 1
  ps -p "$PID" >/dev/null
  if [ $? -ne 0 ]; then
    # Process died an early death
    rm "$PID_FILE"
    echo "$PROG: error: did not start (see log for details: $LOG_FILE)" >&2
    return 1
  fi

  echo "Started"
  return 0
}

stop() {
  if [ -f "$PID_FILE" ]; then
    PID=`cat "$PID_FILE"`
    kill "$PID" 2>/dev/null
    rm "$PID_FILE"
    echo "Stopped"
  else
    echo "Was not running"
  fi
  return 0
}

status() {
  if [ -f "$PID_FILE" ]; then
    PID=`cat "$PID_FILE"`
    ps -p "$PID" >/dev/null
    if [ $? -eq 0 ]; then
      echo "Running"
      return 0
    else
      echo "Died"
      return 2
    fi
  else
    echo "Not running"
    return 1
  fi
}

help() {
  echo "Usage: $PROG [-h|--help] {start|stop|restart|status}"
}

# Check if configured correctly

if [ ! -d "$INST_DIR" ]; then
  echo "$PROG: error: not installed in expected location: $INST_DIR" >&2
  exit 1
fi
if [ ! -d "$VAR_DIR" ]; then
  echo "$PROG: error: log/pid directory not found: $VAR_DIR" >&2
  exit 1
fi

# Process arguments

case "$1" in
start)     start; STATUS=$?;;
stop)      stop; STATUS=$?;;
restart)   stop && start; STATUS=$?;;
status)    status; STATUS=$?;;
-h|--help) help; STATUS=0;;
*)         echo "$PROG: usage error (-h for help)" >&2; STATUS=1;;
esac

exit $STATUS

#EOF
