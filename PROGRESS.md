# 진행 상황 (다음에 이어서 할 곳)

> 마지막 갱신: 2026-11-13

## 지금 위치
**과제 6 시작 전** (과제 3 완료)

| 과제 | 상태 |
| --- | --- |
| 1 | ✅ 완료 |
| 2 | ✅ 완료 |
| 3 | ✅ 완료 |
| 4 ~ 6 | ⏳ 대기 |

## 서버 상태

| 서버 | 상태 | 관리 IP | 마지막 스냅샷 |
| --- | --- | --- | --- |
| node1 | Rocky 9.8, nginx + Keepalived MASTER(VIP .100), Galera 노드 | 192.168.56.11 | `과제3완료` |
| node2 | Rocky 9.8, nginx + Keepalived BACKUP, Galera 노드 | 192.168.56.12 | `과제3완료` |
| node3 | Rocky 8.10, bond0, Galera 노드(MariaDB 10.5) | 192.168.56.13 | `과제3완료` |

스냅샷은 반드시 VM을 끄고 찍는다(live 스냅샷 멈춤 장애 이후).

## 남은 순서
1. 과제 6 백업 스크립트 (초안 backup.sh, remote_backup.sh 실행 · 검증 · cron)
2. 과제 4 · 5: CONCEPTS.md 검토, README에 "개념 위주 정리" 표시

## 다시 켤 때 주의
세 VM을 모두 끄면 Galera 클러스터가 내려간다. `/var/lib/mysql/grastate.dat`에서 `safe_to_bootstrap: 1`(또는 seqno가 가장 큰) 노드에서 `galera_new_cluster`, 나머지는 `systemctl start mariadb`.
