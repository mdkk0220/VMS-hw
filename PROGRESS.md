# 진행 상황 (다음에 이어서 할 곳)

> 마지막 갱신: 2026-11-13

## 지금 위치
**과제 6 완료** → 과제 4 · 5 문서 검토

| 과제 | 상태 |
| --- | --- |
| 1 | ✅ 완료 |
| 2 | ✅ 완료 |
| 3 | ✅ 완료 |
| 4 · 5 | 📄 CONCEPTS.md 작성 (개념 위주) |
| 6 | ✅ 완료 |

## 서버 상태

| 서버 | 상태 | 관리 IP | 마지막 스냅샷 |
| --- | --- | --- | --- |
| node1 | Rocky 9.8, nginx + Keepalived MASTER(VIP .100), Galera 노드, 백업 스크립트 · cron | 192.168.56.11 | `과제6-복구테스트완료` |
| node2 | Rocky 9.8, nginx + Keepalived BACKUP, Galera 노드 | 192.168.56.12 | `과제3완료` |
| node3 | Rocky 8.10, bond0, Galera 노드(MariaDB 10.5), 백업 서버(backup 계정) | 192.168.56.13 | `과제6-복구테스트완료` |

스냅샷은 반드시 VM을 끄고 찍는다(live 스냅샷 멈춤 장애 이후).

## 남은 순서
1. (완료 11/13) 과제 4 · 5 CONCEPTS.md 검토, README에 "개념 위주 정리" 표시
2. node2 다음에 켤 때: index.html 심볼릭 링크를 실제 파일로 교체(node1과 같은 방법)
3. (선택) 과제 5 포트포워딩 실습

## 다시 켤 때 주의
**현재 마지막 종료 노드는 node3** → 다음 기동은 node3에서 `galera_new_cluster`, 이어서 node1 · node2.

세 VM을 모두 끄면 Galera 클러스터가 내려간다. `/var/lib/mysql/grastate.dat`에서 `safe_to_bootstrap: 1`(또는 seqno가 가장 큰) 노드에서 `galera_new_cluster`, 나머지는 `systemctl start mariadb`.
