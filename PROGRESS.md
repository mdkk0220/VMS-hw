# 진행 상황 (다음에 이어서 할 곳)

> 마지막 갱신: 2026-11-12 (오후)

## 지금 위치
**과제 3 · 3-3 Galera 시작 전** (3-1 Keepalived, 3-2 Replication 완료)

| 과제 | 상태 |
| --- | --- |
| 1 | ✅ 완료 |
| 2 | ✅ 완료 |
| 3 | 🔄 3-1 · 3-2 완료 → **다음 3-3 Galera** |
| 4 ~ 6 | ⏳ 대기 |

## 서버 상태

| 서버 | 상태 | 관리 IP | 마지막 스냅샷 |
| --- | --- | --- | --- |
| node1 | Rocky 9.8, nginx + Keepalived MASTER(VIP .100), MariaDB 원본 | 192.168.56.11 | `과제3-replication완료` |
| node2 | Rocky 9.8, nginx + Keepalived BACKUP, MariaDB 복제본 | 192.168.56.12 | `과제3-replication완료` |
| node3 | Rocky 8.10, bond0(10.10.10.13) 정상 | 192.168.56.13 | `과제2완료` |

스냅샷은 반드시 VM을 끄고 찍는다(live 스냅샷 멈춤 장애 이후).

## 남은 순서 (11/13 14:00~18:00)
1. 3-3 Galera: node3에 MariaDB 설치(8.10은 버전 확인 필요), node1·node2 복제 해제, 세 대 wsrep 설정, bootstrap, `wsrep_cluster_size` 3, 노드 1대 중지 · 복귀
2. 과제 6 백업 스크립트 (초안 backup.sh, remote_backup.sh 실행 · 검증 · cron)
3. 과제 4 · 5 정리 문서 검토
