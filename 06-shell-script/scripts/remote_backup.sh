#!/bin/bash
# remote_backup.sh - 원격 서버 파일 가져오기(pull) / 백업 서버로 올리기(push)
# 사용법: ./remote_backup.sh pull   # 원격 서버의 디렉터리를 로컬로 가져오기 (증분, 날짜별 스냅샷)
#         ./remote_backup.sh push   # 로컬 백업 파일을 원격 백업 서버로 올리고 체크섬 검증
set -euo pipefail

REMOTE_USER="${REMOTE_USER:-backup}"
REMOTE_HOST="${REMOTE_HOST:-192.168.56.13}"
SSH_KEY="${SSH_KEY:-$HOME/.ssh/id_ed25519}"
SSH_OPTS=(-i "$SSH_KEY" -o BatchMode=yes -o ConnectTimeout=5)

PULL_SRC="${PULL_SRC:-/etc/my.cnf.d/}"        # 원격에서 가져올 경로 (node3의 Galera 설정)
PULL_DEST="/backup/remote/${REMOTE_HOST}"     # 로컬 저장 위치
PUSH_SRC="${PUSH_SRC:-/backup/local/}"        # 로컬에서 올릴 경로
PUSH_DEST="/backup/from_$(hostname -s)/"      # 원격 저장 위치
REMOTE_RETENTION_DAYS=14
LOG_FILE="${LOG_FILE:-/var/log/remote_backup.log}"

log() { echo "[$(date '+%F %T')] $*" | tee -a "$LOG_FILE"; }
# shellcheck disable=SC2029  # 원격 경로 변수는 일부러 로컬에서 펼쳐 보낸다
rssh() { ssh "${SSH_OPTS[@]}" "${REMOTE_USER}@${REMOTE_HOST}" "$@"; }

check_ssh() {
  if ! rssh true 2>/dev/null; then
    log "ERROR: ${REMOTE_HOST} SSH 접속 실패 (키/방화벽/서비스 확인)"; exit 1
  fi
}

do_pull() {
  local snap last=""
  snap="${PULL_DEST}/$(date +%Y%m%d)"
  mkdir -p "$snap"
  log "PULL: ${REMOTE_HOST}:${PULL_SRC} -> ${snap}"
  # 직전 스냅샷과 같은 파일은 하드링크로 → 매일 전체 복사처럼 보이지만 용량은 바뀐 만큼만
  for d in "${PULL_DEST}"/*/; do [ -d "$d" ] && [ "${d%/}" != "$snap" ] && last="${d%/}"; done
  rsync -az --delete ${last:+--link-dest="$last"} \
    -e "ssh ${SSH_OPTS[*]}" "${REMOTE_USER}@${REMOTE_HOST}:${PULL_SRC}" "$snap/" >>"$LOG_FILE" 2>&1
  log "PULL OK: $(du -sh "$snap" | cut -f1)"
}

do_push() {
  log "PUSH: ${PUSH_SRC} -> ${REMOTE_HOST}:${PUSH_DEST}"
  rssh "mkdir -p '${PUSH_DEST}'"
  rsync -az --partial -e "ssh ${SSH_OPTS[*]}" "$PUSH_SRC" "${REMOTE_USER}@${REMOTE_HOST}:${PUSH_DEST}" >>"$LOG_FILE" 2>&1
  # 원격에서 체크섬 검증: 올라간 파일이 원본과 같은지 확인
  if rssh "cd '${PUSH_DEST}' && for f in *.sha256; do [ -e \"\$f\" ] || continue; sha256sum -c --quiet \"\$f\" || exit 1; done"; then
    log "VERIFY: 원격 체크섬 일치"
  else
    log "ERROR: 원격 체크섬 불일치"; exit 2
  fi
  rssh "find '${PUSH_DEST}' -type f -mtime +${REMOTE_RETENTION_DAYS} -delete"
  log "PUSH OK"
}

case "${1:-}" in
  pull) check_ssh; do_pull ;;
  push) check_ssh; do_push ;;
  *) echo "사용법: $0 {pull|push}"; exit 9 ;;
esac
