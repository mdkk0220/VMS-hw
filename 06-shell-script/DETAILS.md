# 6 · 쉘 스크립트 작성 및 연습 (백업 자동화) · 상세 기록

**요약: [README.md](./README.md)** (이 문서는 명령어와 출력까지 담은 상세 기록)

> (실습 후 작성) 반복 작업인 파일 백업과 원격 서버 백업 · 업로드를 쉘 스크립트로 자동화하고 cron으로 주기 실행한다.

`Bash` `tar` `rsync` `SSH 키 인증` `cron`

## 과제 범위
- 쉘 스크립트로 자동화 스크립트 작성
1. 파일 백업 쉘 스크립트 작성 연습
2. 원격지 서버에서 파일 백업 / 업로드 쉘 스크립트 작성 연습

## 진행 체크리스트
- [ ] 로컬 백업 스크립트: 압축, 체크섬, 보관 주기 삭제, 로그, 중복 실행 방지
- [ ] 복원 테스트 (복원이 되어야 백업이다)
- [ ] SSH 키 인증 설정 (node1 → node3)
- [ ] 원격 백업(pull) · 업로드(push) 스크립트: rsync, 원격 체크섬 검증
- [ ] cron 등록 · 실행 로그 확인

## 폴더 구성
(스크립트 작성 후 추가)

## 실습 과정
(실습 후 작성)

## 결과
(결과 캡처 추가 예정)

## 트러블슈팅
(실습 후 작성)

## 복구 테스트 (11/13)

### R1 · 파일: 실수로 지운 웹 페이지를 백업 서버에서 복원
```bash
rm -f /usr/share/nginx/html/index.html        # 403
LATEST=$(ssh -o BatchMode=yes backup@192.168.56.13 'ls -1t /backup/from_node1/*.tar.gz | head -1')
scp -q -o BatchMode=yes "backup@192.168.56.13:${LATEST}" "backup@192.168.56.13:${LATEST}.sha256" .
sha256sum -c ./*.sha256                        # OK
tar -xzf ./*.tar.gz usr/share/nginx/html/index.html
```
꺼낸 파일이 `index.html -> ../../testpage/index.html` 심볼릭 링크였다. 실제 내용은 `/usr/share/testpage/index.html`(패키지 `rocky-logos-httpd` 소유)에 있었고 백업 대상 밖이었다.

```bash
cp -a /tmp/restore/usr/share/nginx/html/index.html /usr/share/nginx/html/   # 링크 복원 → 여전히 403 (user_tmp_t)
\cp --remove-destination /usr/share/testpage/index.html /usr/share/nginx/html/index.html
restorecon -v /usr/share/nginx/html/index.html                              # httpd_sys_content_t
curl -s http://localhost                                                     # WEB1 - node1
/usr/local/bin/backup.sh >/dev/null && tar -xzOf "$(ls -1t /backup/local/*.tar.gz | head -1)" usr/share/nginx/html/index.html
# WEB1 - node1 (192.168.56.11)  ← 이제 백업에 내용이 들어감
```

### R2 · DB: 실수로 지운 줄만 되돌리기
```bash
mariadb -e "DELETE FROM cafe.sales WHERE item='mocha';"        # Galera라 node3에서도 함께 삭제됨
DUMP=$(ls -1t /backup/local/*_db.sql.gz | head -1)
zcat "$DUMP" | sed -n '/^-- Current Database: `cafe`/,/^-- Current Database: `/p' \
  | sed 's/`cafe`/`cafe_restore`/g' > /tmp/restore/cafe_restore.sql
grep -E "CREATE DATABASE|^USE" /tmp/restore/cafe_restore.sql    # cafe_restore만 있는지 확인 후 진행
mariadb < /tmp/restore/cafe_restore.sql
mariadb -e "INSERT INTO cafe.sales SELECT r.* FROM cafe_restore.sales r
            LEFT JOIN cafe.sales c ON c.id = r.id WHERE c.id IS NULL;"
mariadb -e "DROP DATABASE cafe_restore;"
```
결과: node1 · node3 모두 id 1, 2, 3(mocha), 5, 6, 7. 삭제 직후 화면은 기록하지 못했다.

## 배운 점
(실습 후 작성)

## 연결
- 이전 과제: [5 · 네트워크 기본 개념](../05-network-basics/)
- 처음으로: [VMS-hw](../)
