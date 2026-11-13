# 6 · 쉘 스크립트 작성 및 연습 (백업 자동화)

> 명령어와 출력까지 담은 상세 기록은 [DETAILS.md](./DETAILS.md)에 있고, 스크립트 원본은 [scripts/](./scripts/)에 있습니다.

## 한 줄 요약
node1의 설정 파일 · 웹 페이지 · MariaDB(Galera) 전체를 백업하는 스크립트와, 그 백업을 백업 서버(node3)로 올리고 체크섬으로 검증하는 스크립트를 만들어 cron으로 매일 자동 실행되게 했습니다. 백업 서버에는 백업 전용 계정과 SSH 키로만 접속합니다.

---

## 1. 과제 요구사항과 결과

| 요구사항 | 결과 |
| --- | --- |
| 쉘 스크립트로 자동화 스크립트 생성 | ✅ cron으로 매일 02:30 백업 → 업로드, 03:00 원격 설정 가져오기 |
| 파일 백업 쉘 스크립트 작성 | ✅ [backup.sh](./scripts/backup.sh): tar + 체크섬 + (선택) DB 덤프 + 7일 보관 |
| 원격지 서버 파일 백업 / 업로드 쉘 스크립트 작성 | ✅ [remote_backup.sh](./scripts/remote_backup.sh): push(업로드 + 원격 체크섬 검증) / pull(날짜별 증분 가져오기) |

---

## 2. 실습 환경

| 역할 | 서버 | 내용 |
| --- | --- | --- |
| 백업 대상 · 실행 | node1 (Rocky 9.8, .11) | `/etc`, `/usr/share/nginx/html`, MariaDB 전체 → `/backup/local` |
| 백업 서버 | node3 (Rocky 8.10, .13) | 계정 `backup`, `/backup/from_node1` (권한 750) |
| 접속 방식 | node1 root → node3 backup | ED25519 SSH 키, 비밀번호 없이 (`BatchMode`) |

---

## 3. 만든 스크립트

| 파일 | 하는 일 | 지킨 원칙 |
| --- | --- | --- |
| [backup.sh](./scripts/backup.sh) | `/etc` · 웹 페이지 압축, `DB_DUMP=1`이면 `mariadb-dump --single-transaction`, 각각 sha256 생성, 압축 목록 읽기 검증, 7일 지난 파일 삭제 | 중복 실행 잠금(flock), 필요한 명령 사전 검사, 실패 시 깨진 파일 삭제 후 0이 아닌 코드로 종료, `umask 077` |
| [remote_backup.sh](./scripts/remote_backup.sh) | `push`: rsync 업로드 → **원격에서 체크섬 재계산** → 14일 지난 파일 삭제 / `pull`: 원격 폴더를 날짜별로 가져오되 바뀌지 않은 파일은 하드링크(`--link-dest`) | 접속 사전 확인(실패 시 exit 1), 키 인증만 사용, 필요한 명령 사전 검사 |

**cron** (`/etc/cron.d/vms-backup`)
```
SHELL=/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin
30 2 * * * root DB_DUMP=1 /usr/local/bin/backup.sh >/dev/null 2>&1 && /usr/local/bin/remote_backup.sh push >/dev/null 2>&1
0 3 * * * root /usr/local/bin/remote_backup.sh pull >/dev/null 2>&1
```
`&&`로 연결해 로컬 백업이 실패하면 업로드하지 않습니다. cron은 PATH가 짧아서 맨 위에 직접 적었습니다.

---

## 4. 검증 결과

| 확인 | 결과 |
| --- | --- |
| 로컬 백업 | 파일 4.6MB, DB 덤프 453KB |
| 체크섬 | 두 파일 OK |
| 압축 안 내용 | `etc/keepalived/keepalived.conf`, `usr/share/nginx/html/index.html` 포함 |
| DB 덤프 안 내용 | `cafe.sales` INSERT 포함 |
| 업로드 | node3에서 다시 계산한 체크섬이 원본과 일치 |
| 가져오기 | node3 `/etc/my.cnf.d/`(galera.cnf 등 8개)를 `/backup/remote/192.168.56.13/20261113/`로 |
| 실패 재현 | 없는 주소로 업로드 → `ERROR: … SSH 접속 실패`, exit 1 |
| cron | 시험용 매분 일정으로 자동 실행 2회 확인 후 정식 일정으로 변경 |
| **복구 R1 (파일)** | index.html 삭제(403) → **node3의 백업**에서 그 파일만 꺼내 복원 → WEB1 응답 |
| **복구 R2 (DB)** | 덤프에서 cafe DB만 `cafe_restore`로 복원 → 지금 없는 id만 되돌림 → node1 · node3 모두 6줄 (삭제 직후 화면은 미확인) |

---

## 5. 겪은 장애와 해결

| # | 장애 | 원인 | 해결 |
| --- | --- | --- | --- |
| 1 | `ERROR: tar 실패`, 백업 파일 없음 | Rocky 최소 설치에 `tar`가 없음 | `dnf install tar`. 스크립트에 **필요한 명령 사전 검사** 추가 → 이제 `'tar' 명령이 없음`으로 원인을 바로 알려 줌 |
| 2 | 백업 파일이 `-rw-r--r--` | 기본 umask 022. tar 안에 `/etc/shadow`, 덤프에 DB 전체가 있어 일반 계정도 읽을 수 있었음 | 스크립트에 `umask 077`, 기존 파일 `chmod 600` |
| 3 | 고친 스크립트를 내려받았는데 옛 버전 | GitHub raw 주소의 캐시 | 커밋 번호가 들어간 주소로 내려받아 버전 고정 |
| 4 | (예방) pull 대상 `/etc/`를 backup 계정이 다 읽지 못함 | `/etc/shadow` 등은 root만 읽기 가능 | pull 대상을 `/etc/my.cnf.d/`로 변경 |
| 5 | **복구 테스트에서 발견:** 백업 속 index.html에 내용이 없음 | Rocky nginx의 `index.html`은 `../../testpage/index.html`로 가는 **심볼릭 링크**. 우리 페이지 내용은 패키지(`rocky-logos-httpd`) 소유 파일에 있었고, tar는 링크만 담음 | 링크를 실제 파일로 교체(`\cp --remove-destination`), 새 백업에서 `tar -xzOf`로 내용 확인 |
| 6 | 링크를 되살렸는데도 403 | `cp -a`가 `/tmp`의 SELinux 이름표(`user_tmp_t`)까지 복사 | `restorecon` → `httpd_sys_content_t` |
| 7 | 교체 명령이 실행되지 않음 | root의 `cp`는 `cp -i` 별칭이라 덮어쓰기를 물었고, 붙여 넣은 다음 줄이 그 대답으로 들어감 | `\cp`로 별칭 무시, 한 줄씩 실행 |

시작 전 준비로, 세 대를 모두 껐던 Galera를 `safe_to_bootstrap: 1`인 node3에서 `galera_new_cluster`로 다시 살렸습니다(과제 3 기록 참고).

---

## 6. 배운 핵심 개념

| 개념 | 한 줄 설명 |
| --- | --- |
| 백업 3단 확인 | 체크섬(손상 없음) · 압축 목록(필요한 파일이 있음) · 덤프 내용(데이터가 있음). 있다고 끝이 아니라 복구할 수 있어야 백업 |
| 다른 곳에 한 벌 더 | 로컬 백업만 있으면 디스크 장애에 함께 사라짐 |
| 복구 테스트 | 체크섬 · 목록 검사를 통과해도 내용이 빠질 수 있음(심볼릭 링크). 실제로 복원해 봐야 안다 |
| 이중화 ≠ 백업 | Galera는 실수로 지운 데이터도 모든 노드에 그대로 복제. 되돌리려면 백업이 필요 |
| 부분 복원 | 덤프를 그대로 덮지 않고 다른 이름으로 풀어 필요한 줄만 옮김. 백업 이후 데이터를 지킴 |
| 최소 권한 | 백업 서버에는 root 대신 `/backup`만 쓰는 전용 계정 |
| SSH 키 인증 | cron처럼 사람이 없을 때 비밀번호 없이 접속. `BatchMode=yes`로 같은 조건 시험 |
| 실패는 크게 | 실패하면 로그를 남기고 0이 아닌 코드로 끝내야 모니터링이 잡음 |
| `--single-transaction` | 서비스를 멈추지 않고 한 시점 기준으로 일관된 DB 덤프 |
| `--link-dest` | 바뀌지 않은 파일은 하드링크로, 매일 전체 복사처럼 보이지만 용량은 바뀐 만큼만 |

---

## 7. 한 문단 설명
백업 스크립트는 압축과 DB 덤프를 만든 뒤 체크섬, 압축 목록, 덤프 내용을 확인해 "복구할 수 있는 백업"인지 검증하고, 백업 서버로 올린 뒤 원격에서도 체크섬을 다시 확인합니다. 실습 중 최소 설치 서버에 tar가 없어서 실패한 일과, 백업 파일이 누구나 읽을 수 있는 권한으로 만들어지는 문제를 찾아 필요한 명령 사전 검사와 `umask 077`을 넣었습니다. cron에는 PATH를 직접 적고, 로컬 백업이 성공했을 때만 업로드하도록 연결했습니다. 마지막으로 실제 복구를 해 보니 웹 페이지가 심볼릭 링크라 백업에 내용이 빠져 있었고, 실제 파일로 바꿔 백업 범위 안에 넣은 뒤 파일과 DB 모두 복원되는 것을 확인했습니다.

## 8. 미실시 · 남은 일
- 정식 일정(02:30)의 실제 실행 확인
- node2의 index.html도 같은 심볼릭 링크 구조라, 다음에 켤 때 실제 파일로 교체 필요
