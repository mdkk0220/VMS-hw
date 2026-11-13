#!/bin/bash
# backup.sh - 로컬 파일 백업 + (선택) MariaDB 덤프 + 보관 주기 관리
# 사용법: ./backup.sh [백업대상1 백업대상2 ...]
#   인자가 없으면 /etc 와 /usr/share/nginx/html 을 백업한다.
#   DB_DUMP=1 ./backup.sh  → MariaDB 전체 덤프도 함께 만든다.
set -euo pipefail

if [ $# -gt 0 ]; then SRC_DIRS=("$@"); else SRC_DIRS=(/etc /usr/share/nginx/html); fi
DEST_DIR="${DEST_DIR:-/backup/local}"
RETENTION_DAYS="${RETENTION_DAYS:-7}"
LOG_FILE="${LOG_FILE:-/var/log/backup.log}"
DB_DUMP="${DB_DUMP:-0}"
DATE=$(date +%Y%m%d_%H%M%S)
HOST=$(hostname -s)
ARCHIVE="${DEST_DIR}/${HOST}_${DATE}.tar.gz"
DUMP="${DEST_DIR}/${HOST}_${DATE}_db.sql.gz"

log() { echo "[$(date '+%F %T')] $*" | tee -a "$LOG_FILE"; }

# 같은 스크립트가 두 번 동시에 돌지 않게 잠금
exec 9>/var/lock/backup.lock
flock -n 9 || { log "ERROR: 이미 실행 중"; exit 1; }

mkdir -p "$DEST_DIR"

for d in "${SRC_DIRS[@]}"; do
  [ -e "$d" ] || { log "ERROR: 대상 없음 $d"; exit 2; }
done

# 1) 파일 백업
log "START: ${SRC_DIRS[*]} -> $ARCHIVE"
if tar -czpf "$ARCHIVE" "${SRC_DIRS[@]}" 2>>"$LOG_FILE"; then
  # 체크섬은 파일 이름만 기록 → 원격 서버로 옮겨도 sha256sum -c 로 검사 가능
  (cd "$DEST_DIR" && sha256sum "${ARCHIVE##*/}" > "${ARCHIVE##*/}.sha256")
  log "OK: 파일 백업 $(du -h "$ARCHIVE" | cut -f1)"
else
  log "ERROR: tar 실패"; rm -f "$ARCHIVE"; exit 3
fi
tar -tzf "$ARCHIVE" > /dev/null && log "VERIFY: 압축 목록 읽기 정상"

# 2) DB 덤프 (선택)
if [ "$DB_DUMP" = "1" ]; then
  log "DB: mariadb-dump 시작"
  # --single-transaction: 서비스를 멈추지 않고 한 시점의 데이터를 일관되게 덤프 (InnoDB)
  if mariadb-dump --all-databases --single-transaction --routines --events 2>>"$LOG_FILE" | gzip > "$DUMP"; then
    (cd "$DEST_DIR" && sha256sum "${DUMP##*/}" > "${DUMP##*/}.sha256")
    log "OK: DB 덤프 $(du -h "$DUMP" | cut -f1)"
  else
    log "ERROR: DB 덤프 실패"; rm -f "$DUMP"; exit 4
  fi
fi

# 3) 보관 주기 지난 백업 삭제
DELETED=$(find "$DEST_DIR" -name "${HOST}_*" -type f -mtime +"$RETENTION_DAYS" -print -delete | wc -l)
log "CLEAN: ${RETENTION_DAYS}일 지난 파일 ${DELETED}개 삭제"
log "END"
