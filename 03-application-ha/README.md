# 3 · Application(WEB · MariaDB) 단 이중화 · 다중화 구성 및 테스트

> 명령어와 출력까지 담은 상세 기록은 [DETAILS.md](./DETAILS.md)에 있습니다.

## 한 줄 요약
node1 · node2에 nginx와 Keepalived를 올려 **VIP 192.168.56.100**으로 웹을 이중화했고, nginx만 죽어도 약 4초 안에 반대편으로 넘어가는 것을 확인했습니다. 이어서 MariaDB를 **node1 → node2로 GTID 복제**하고, 복제본에 직접 써서 복제가 멈추는 장애를 재현 · 복구했습니다. 마지막으로 Rocky 9.8 두 대와 8.10 한 대를 **Galera 3노드 클러스터**로 묶어 어느 노드에 써도 모두 반영되고, 한 대가 빠져도 쓰기가 계속되는 것을 확인했습니다.

---

## 1. 과제 요구사항과 결과

| 요구사항 | 결과 |
| --- | --- |
| WEB 이중화 구성 방법 확인 후 구현 | ✅ nginx + Keepalived, VIP 전환 시 빈 응답 1~2회(2~4초) |
| DB 이중화 구성 방법 확인 후 구현 | ✅ MariaDB 10.5 Replication(GTID), 충돌 장애 재현 · 복구 |
| DB 다중화 구성 방법 확인 및 구현 | ✅ Galera 3노드, `wsrep_cluster_size` 3 · Synced · Primary, 노드 1대 장애 중에도 쓰기 가능 |

---

## 2. 실습 환경

| 구분 | node1 | node2 | node3 |
| --- | --- | --- | --- |
| OS | Rocky 9.8 | Rocky 9.8 | Rocky 8.10 |
| 관리망 IP | 192.168.56.11 | 192.168.56.12 | 192.168.56.13 |
| WEB | nginx, 페이지 `WEB1` | nginx, 페이지 `WEB2` | |
| Keepalived | MASTER, priority 110 | BACKUP, priority 100 | |
| VIP | 192.168.56.100 (평소) | 장애 시 넘겨받음 | |
| 3-2 Replication | 원본 `server_id=1` | 복제본 `read_only` | |
| 3-3 Galera (`vms_galera`) | 노드 (bootstrap) | 노드 | 노드 (MariaDB 10.5 모듈) |

---

## 3. 수행한 작업 (순서대로)

| # | 작업 | 확인 |
| --- | --- | --- |
| 1 | 두 서버에 nginx · keepalived 설치, 방화벽 http · VRRP 허용 | 내 PC에서 각 서버 페이지 응답 |
| 2 | Keepalived 설정: VIP, priority, nginx 검사(track_script, 실패 시 -30) | node1에만 VIP |
| 3 | 검사 스크립트가 SELinux에 막혀 꺼진 것을 발견 → `/usr/libexec/keepalived/`로 옮김 | `VRRP_Script(chk_nginx) succeeded` |
| 4 | 장애 전환: nginx만 중지 / keepalived 중지 | WEB1 → WEB2 → WEB1, 빈 응답 2회 / 1회 |
| 5 | 두 서버에 MariaDB 설치, node1 binlog · node2 read_only | `server_id` 1 / 2 |
| 6 | 복제 계정 생성, node2를 GTID로 node1에 연결 | `Slave_IO/SQL_Running: Yes`, GTID 일치 |
| 7 | node1에 데이터 입력 → node2에 자동 반영 | 같은 데이터, GTID `0-1-5` |
| 8 | 장애 재현: node2에 직접 쓰기 → 1062 충돌로 SQL 스레드 정지 → 복구 | GTID `0-1-6` 일치, 데이터 일치 |
| 9 | node3(8.10)에 MariaDB **10.5 모듈** 설치(기본값 10.3), SELinux에 Galera 포트 등록 | `mysqld_port_t`에 4444 · 4567 · 4568 |
| 10 | 복제 해제, 세 서버 Galera 설정, node1 bootstrap → node2 · node3 합류(SST) | `wsrep_cluster_size` 3, Synced, Primary |
| 11 | node2 · node3에 각각 INSERT, node3 정지 중 node1에 INSERT → node3 복귀 | 세 노드 모두 6줄 |

스냅샷: `과제2완료` → `과제3-keepalived완료` → `과제3-replication완료` → `과제3완료` (모두 전원 끈 상태)

---

## 4. 겪은 장애와 해결

| # | 장애 | 원인 | 해결 |
| --- | --- | --- | --- |
| 1 | nginx를 꺼도 VIP가 안 넘어갈 상태 (검사 꺼짐, 겉으로는 정상) | SELinux가 Keepalived의 `systemctl` 실행을 막아 track_script가 자동 비활성화 | 검사 스크립트를 SELinux 허용 경로 `/usr/libexec/keepalived/`에 두고 `restorecon` |
| 2 | 켜진 채로 찍은 스냅샷이 90%에서 1시간 멈춤 → node1이 `<inaccessible>` | live 스냅샷이 끝나지 못한 채 강제 종료되어 설정 파일에 빈 디스크 조각 등록이 남음 | 설정 파일 백업 후 그 등록 한 줄만 삭제 → 복구, 작업 손실 없음. 이후 스냅샷은 끄고 찍음 |
| 3 | 복제 정지 `Duplicate entry '3'` (1062) | 복제본에 직접 INSERT. `read_only`는 root를 막지 못함 | 원본 기준으로 복제본의 잘못된 줄 삭제 후 `START SLAVE` |
| 4 | node3가 Galera에 합류할 수 없는 상태 | 8.10 SELinux 정책에 Galera 포트가 없음(4567은 `tram_port_t`, 4444는 `kerberos_port_t`, 4568 미등록), 기본 MariaDB가 10.3 | `semanage port -m/-a -t mysqld_port_t`, `dnf module enable mariadb:10.5` |

---

## 5. 배운 핵심 개념

| 개념 | 한 줄 설명 |
| --- | --- |
| VIP · VRRP | 손님은 대표 주소 하나로 접속하고, 그 주소를 누가 가질지는 VRRP 신호로 정함 |
| priority · track_script | 서버가 아니라 **서비스** 상태로 우선순위를 깎아 넘김 |
| gratuitous ARP | VIP 주인이 바뀌었다고 네트워크에 알리는 방송 |
| binlog · server_id | 원본의 변경 일지, 서버마다 다른 번호 |
| IO / SQL 스레드 | 일지를 가져오는 일꾼 / 실행하는 일꾼. 둘 다 Yes여야 정상 |
| GTID | 변경마다 붙는 전역 번호. 두 서버 번호가 같으면 빠진 변경이 없음 |
| ROW 형식 | 계산 결과를 보내서 `NOW()` 같은 값도 원본과 똑같이 남음 |
| Galera · Multi-Master | 세 노드가 모두 쓰기를 받고, 변경은 노드들의 합의를 거쳐 확정 |
| 쿼럼 · Primary | 과반(3대 중 2대)이 모여 있어야 쓰기 가능한 상태(Primary) |
| bootstrap | 처음 한 대만 `galera_new_cluster`로 새 클러스터를 시작 |
| SST · IST | 데이터 전체 복사(새 노드) / 빠진 변경만 받기(잠깐 빠졌던 노드). node3 복귀 때 `Receiving IST: 3 writesets, seqnos 6-8`로 IST 확인 |
| auto_increment 간격 | 노드끼리 번호가 겹치지 않게 간격을 둠. id가 건너뛰어도 유실이 아님 |

---

## 6. 한 문단 설명
Keepalived로 VIP를 node1에 두고, nginx 상태를 2초마다 검사해 서비스가 죽으면 우선순위를 낮춰 node2로 넘기도록 했습니다. 검사 스크립트가 SELinux에 막혀 조용히 꺼져 있던 것을 로그에서 찾아, SELinux를 끄지 않고 허용된 경로로 옮겨 해결했습니다. DB는 MariaDB GTID 복제로 node1의 변경이 node2에 그대로 반영되는 것을 확인했고, 복제본에 직접 쓰면 키 충돌로 SQL 스레드가 멈춘다는 것을 재현해 원본 기준으로 복구했습니다. Galera에서는 같은 쓰기가 세 노드 어디서든 충돌 없이 반영됐고, 한 대가 빠져도 과반이 남아 쓰기가 계속됐습니다. 8.10 노드는 MariaDB 버전과 SELinux 포트 정책이 9.8과 달라 직접 맞춰야 했습니다.

---

## 7. 다시 켤 때 주의 (Galera 전체 재시작)
세 노드를 모두 끄면 클러스터가 사라진다. 다시 켤 때는 **마지막에 꺼진(가장 최신) 노드에서만** `galera_new_cluster`로 시작하고, 나머지는 `systemctl start mariadb`로 합류시킨다. 어느 노드가 최신인지는 `/var/lib/mysql/grastate.dat`의 `seqno`와 `safe_to_bootstrap: 1`로 판단한다.

## 8. 미실시 · 미확인
- VM을 갑자기 끄는 장애 전환, 복제 수동 페일오버
