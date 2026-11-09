# 3 · Application(WEB · MariaDB) 단 이중화 · 다중화 구성 및 테스트 · 상세 기록

**요약: [README.md](./README.md)** (이 문서는 명령어와 출력까지 담은 상세 기록)

> (실습 후 작성) 웹 서버와 DB 서버 한 대가 멈춰도 서비스가 이어지도록 이중화 · 다중화를 구성하고 장애 전환을 확인한다.

`Nginx` `Keepalived` `VRRP` `MariaDB Replication` `Galera Cluster`

## 과제 범위
1. WEB 이중화 구성 방법 확인 후 구현
2. DB 이중화 구성 방법 확인 후 구현
3. DB 다중화 구성 방법 확인 및 구현

## 진행 체크리스트
- [ ] WEB 이중화: node1 · node2에 Nginx + Keepalived, VIP 192.168.56.100
- [ ] WEB 장애 테스트: nginx 중지, VM 강제 종료 시 VIP 전환 확인
- [ ] DB 이중화: MariaDB Primary-Replica (GTID) 구성, 복제 상태 확인
- [ ] DB 이중화 테스트: 복제 지연 · 수동 페일오버
- [ ] DB 다중화: Galera Cluster 3노드 구성, `wsrep_cluster_size` 3 확인
- [ ] DB 다중화 테스트: 노드 1대 중지 · 복귀, 전체 재기동(bootstrap), quorum 확인
- [ ] Replication과 Galera 비교 정리

## 실습 과정
(실습 후 작성)

## 결과
(결과 캡처 추가 예정)

## 트러블슈팅
(실습 후 작성)

## 배운 점
(실습 후 작성)

## 연결
- 이전 과제: [2 · 네트워크 이중화(Bonding)](../02-network-bonding/)
- 다음 과제: [4 · Windows 11 최적화](../04-windows11-optimization/)
