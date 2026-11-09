# VMS-hw · 가상화 환경 인프라 실습

> 가상화 환경에서 Rocky Linux 서버를 직접 구축하고, 네트워크 · 애플리케이션 이중화와 자동화를 실습한 기록이다.
> 각 과제마다 무엇을 했고, 어떻게 확인했고, 어떤 문제를 어떻게 해결했는지 남긴다.

`VirtualBox` `Rocky Linux 9.8` `Rocky Linux 8.10` `NetworkManager(nmcli)` `Bonding` `Keepalived` `MariaDB` `Shell Script`

## 과제 목록

| 번호 | 주제 | 상태 | 핵심 산출물 |
|---|---|---|---|
| 1 | [OS(Rocky Linux 9.x & 8.10) 설치 및 외부 통신 테스트](./01-os-install-network-test/) | 완료 | VM 2대 구축, 통신 점검, 장애 5건 해결 · [요약](./01-os-install-network-test/SUMMARY.md) |
| 2 | [네트워크 이중화(Bonding) 구성 테스트](./02-network-bonding/) | 예정 | |
| 3 | [Application(WEB · MariaDB) 이중화 · 다중화](./03-application-ha/) | 예정 | |
| 4 | [Windows 11 최적화 적용 및 테스트](./04-windows11-optimization/) | 예정 | |
| 5 | [네트워크 기본 개념 (L2 · L3 · L4, 라우팅, 포워딩)](./05-network-basics/) | 예정 | |
| 6 | [쉘 스크립트 자동화 (백업 · 원격 업로드)](./06-shell-script/) | 예정 | |

## 실습 환경

| 항목 | 내용 |
|---|---|
| 호스트 | Windows 11 · RAM 16 GB · CPU 가상화(VT-x) 사용 |
| 하이퍼바이저 | Oracle VirtualBox 7.x |
| 게스트 공통 사양 | 2 vCPU · 2 GB RAM · 20 GB 디스크(동적 할당) · Minimal Install |

| 서버 | OS | NAT (enp0s3) | 호스트 전용 (enp0s8) | 용도 |
|---|---|---|---|---|
| node1 | Rocky Linux 9.8 | 10.0.2.15 (DHCP) | 192.168.56.11 (고정) | WEB1 · DB1 · bonding |
| node2 | Rocky Linux 9.x (node1 복제 예정) | 10.0.2.15 (DHCP) | 192.168.56.12 (고정) | WEB2 · DB2 |
| node3 | Rocky Linux 8.10 | 10.0.2.15 (DHCP) | 192.168.56.13 (고정) | DB3 · 백업 서버 |

- **NAT**: VM마다 따로 생기는 가상 공유기. 인터넷으로 나가는 길이다. VM끼리는 이 길로 통신할 수 없다.
- **호스트 전용 네트워크**: 호스트 PC(192.168.56.1)와 VM들이 서로 통신하는 내부 길이다. SSH와 이중화 실습은 모두 이 네트워크를 쓴다.
- 위 IP는 VirtualBox 내부 실습용 사설 주소다.

## 폴더 구성

```text
VMS-hw/
├── README.md                        # 전체 목차와 실습 환경 (이 문서)
├── 01-os-install-network-test/      # 과제 1
├── 02-network-bonding/              # 과제 2
├── 03-application-ha/               # 과제 3
├── 04-windows11-optimization/       # 과제 4
├── 05-network-basics/               # 과제 5
└── 06-shell-script/                 # 과제 6
```
