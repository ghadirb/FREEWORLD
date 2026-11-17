#!/usr/bin/env bash
# تست یکپارچهٔ چندنفره: سرور واقعی + چند بات، شامل راه‌اندازی مجدد سرور.
# استفاده: tests/integration.sh [مسیر godot]
set -u
GODOT="${1:-godot}"
PORT=17777
DATA="$(mktemp -d)"
LOG="$(mktemp -d)"
FAILS=0
SERVER_PID=""

start_server() {
  FREEWORLD_ADMIN="root:topsecret" "$GODOT" --headless --path . -- --server --port "$PORT" --seed 4242 --data-dir "$DATA" >>"$LOG/server.log" 2>&1 &
  SERVER_PID=$!
  for _ in $(seq 1 60); do
    grep -q "listening on port" "$LOG/server.log" 2>/dev/null && return 0
    sleep 0.25
  done
  echo "server did not start"; cat "$LOG/server.log"; exit 1
}

stop_server() {
  sleep 2          # بگذار ذخیره‌سازی تأخیری انجام شود
  kill -TERM "$SERVER_PID" 2>/dev/null
  wait "$SERVER_PID" 2>/dev/null
}

bot() { # سناریو نام [فایل-توکن] [رمز]
  "$GODOT" --headless --path . --script res://tests/bot.gd -- \
    --scenario "$1" --name "$2" --port "$PORT" --token-file "${3:-}" --secret "${4:-}" 2>&1 \
    | grep -E "^\[bot"
  return "${PIPESTATUS[0]}"
}

run() { # عنوان + دستور
  local title="$1"; shift
  "$@" >"$LOG/$title.log" 2>&1
  local rc=$?
  cat "$LOG/$title.log"
  if [ $rc -ne 0 ]; then echo "### $title: FAILED (rc=$rc)"; FAILS=$((FAILS+1)); else echo "### $title: passed"; fi
}

echo "== phase 1: two players online together =="
start_server
bot observer bob "$DATA/bob.token" >"$LOG/observer.log" 2>&1 &
OBS=$!
sleep 1.5
bot builder alice "$DATA/alice.token" >"$LOG/builder.log" 2>&1
B_RC=$?
wait "$OBS"; O_RC=$?
cat "$LOG/builder.log" "$LOG/observer.log"
[ $B_RC -ne 0 ] && { echo "### builder FAILED"; FAILS=$((FAILS+1)); } || echo "### builder passed"
[ $O_RC -ne 0 ] && { echo "### observer FAILED"; FAILS=$((FAILS+1)); } || echo "### observer passed"
run badauth bot badauth alice "$DATA/wrong.token"
echo "wrongtoken" > "$DATA/wrong.token"
run badauth bot badauth alice "$DATA/wrong.token"
stop_server

echo "== phase 2: server restarted, data must survive =="
start_server
run persist bot persist alice "$DATA/alice.token"
run admin bot admin root "" topsecret
stop_server

echo "== phase 3: corrupted save is not silently replaced =="
echo "{ broken" > "$DATA/city_1.json"
rm -f "$DATA/city_1.json.bak"
FREEWORLD_ADMIN="root:topsecret" timeout 20 "$GODOT" --headless --path . -- --server --port "$PORT" --data-dir "$DATA" >"$LOG/corrupt.log" 2>&1
if grep -q "refusing to start" "$LOG/corrupt.log"; then echo "### corrupt-save guard passed"; else echo "### corrupt-save guard FAILED"; FAILS=$((FAILS+1)); fi

echo
if [ "$FAILS" -eq 0 ]; then echo "INTEGRATION: ALL PASSED"; else echo "INTEGRATION: $FAILS FAILED"; echo "--- server log ---"; cat "$LOG/server.log"; fi
exit "$FAILS"
