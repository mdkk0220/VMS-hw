# 2 · OS(Rocky Linux 9.x & 8.10) 네트워크 이중화(Bonding) 구성 테스트 · 상세 기록

**요약: [README.md](./README.md)** (이 문서는 명령어와 출력까지 담은 상세 기록)

> (실습 후 작성) NIC 여러 개를 하나의 가상 인터페이스로 묶어, 랜카드나 케이블 하나가 고장 나도 통신이 유지되는지 확인한다.

`Bonding` `active-backup` `nmcli` `NetworkManager`

## 과제 범위
1. 네트워크 bonding 구성 종류 확인
2. bonding 1개 구성 (Active-Backup)
3. bonding 2개 구성 (Active-Backup)
4. bonding 트러블슈팅

## 진행 체크리스트
- [ ] bonding 모드 0~6 비교 정리
- [ ] node1 · node2에 NIC 추가 (내부 네트워크)
- [ ] bond0 (active-backup) 구성 · `/proc/net/bonding/bond0` 확인
- [ ] 케이블 해제 장애 테스트 · ping 유실 개수 기록 · 복구 확인
- [ ] bond0 + bond1 구성 · 기본 경로 1개 확인
- [ ] 재부팅 후 유지 확인
- [ ] 일부러 낸 장애 3개 재현과 복구 (기존 연결 충돌, autoconnect off, 게이트웨이 중복)
- [ ] Rocky 8.10에서도 동일하게 구성되는지 확인

## 실습 과정
(실습 후 작성)

## 결과
(결과 캡처 추가 예정)

## 트러블슈팅
(실습 후 작성)

## 배운 점
(실습 후 작성)

## 연결
- 이전 과제: [1 · OS 설치 및 외부 통신 테스트](../01-os-install-network-test/)
- 다음 과제: [3 · Application 이중화 · 다중화](../03-application-ha/)
