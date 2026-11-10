# VMS-hw · 가상화 환경 인프라 실습

> 가상화 환경에서 Rocky Linux 서버를 직접 구축하고, 네트워크 · 애플리케이션 이중화와 자동화를 실습한 기록이다.
> 각 과제마다 무엇을 했고, 어떻게 확인했고, 어떤 문제를 어떻게 해결했는지 남긴다.

`VirtualBox` `Rocky Linux 9.8` `Rocky Linux 8.10` `NetworkManager(nmcli)` `Bonding` `Keepalived` `MariaDB` `Shell Script`

## 과제 목록

| 번호 | 주제 (요약) | 상태 | 핵심 산출물 | 상세 기록 | 개념 정리 |
|---|---|---|---|---|---|
| 1 | [OS(Rocky Linux 9.x & 8.10) 설치 및 외부 통신 테스트](./01-os-install-network-test/) | 완료 | VM 2대 구축, 통신 점검, 장애 5건 해결 | [DETAILS](./01-os-install-network-test/DETAILS.md) | - |
| 2 | [네트워크 이중화(Bonding) 구성 테스트](./02-network-bonding/) | 진행 중 | bond 2개 구성, 장애 전환 손실 1~2개, 장애 5건 기록 | [DETAILS](./02-network-bonding/DETAILS.md) | [CONCEPTS](./02-network-bonding/CONCEPTS.md) |
| 3 | [Application(WEB · MariaDB) 이중화 · 다중화](./03-application-ha/) | 예정 | | [DETAILS](./03-application-ha/DETAILS.md) | - |
| 4 | [Windows 11 최적화 적용 및 테스트](./04-windows11-optimization/) | 예정 | | [DETAILS](./04-windows11-optimization/DETAILS.md) | - |
| 5 | [네트워크 기본 개념 (L2 · L3 · L4, 라우팅, 포워딩)](./05-network-basics/) | 예정 | | [DETAILS](./05-network-basics/DETAILS.md) | - |
| 6 | [쉘 스크립트 자동화 (백업 · 원격 업로드)](./06-shell-script/) | 예정 | | [DETAILS](./06-shell-script/DETAILS.md) | - |

각 과제 폴더는 아래 문서로 구성된다.
- `README.md`: 표로 정리한 **요약**. 폴더에 들어가면 먼저 보인다.
- `DETAILS.md`: 명령어, 출력, 장애 분석까지 담은 **상세 기록**.
- `CONCEPTS.md`: 실습 전에 정리한 **개념과 용어** (있는 과제만).

> 다음에 이어서 할 곳: [PROGRESS.md](./PROGRESS.md)

## 실습 환경

| 항목 | 내용 |
|---|---|
| 호스트 | Windows 11 · RAM 16 GB · CPU 가상화(VT-x) 사용 |
| 하이퍼바이저 | Oracle VirtualBox 7.x |
| 게스트 공통 사양 | 2 vCPU · 2 GB RAM · 20 GB 디스크(동적 할당) · Minimal Install |

| 서버 | OS | NAT (enp0s3) | 호스트 전용 (enp0s8) | 용도 |
|---|---|---|---|---|
| node1 | Rocky Linux 9.8 | 10.0.2.15 (DHCP) | 192.168.56.11 (고정) | WEB1 · DB1 · bonding |
| node2 | Rocky Linux 9.8 (node1 복제) | 10.0.2.15 (DHCP) | 192.168.56.12 (고정) | WEB2 · DB2 |
| node3 | Rocky Linux 8.10 | 10.0.2.15 (DHCP) | 192.168.56.13 (고정) | DB3 · 백업 서버 |

- **NAT**: VM마다 따로 생기는 가상 공유기. 인터넷으로 나가는 길이다. VM끼리는 이 길로 통신할 수 없다.
- **호스트 전용 네트워크**: 호스트 PC(192.168.56.1)와 VM들이 서로 통신하는 내부 길이다. SSH와 이중화 실습은 모두 이 네트워크를 쓴다.
- 위 IP는 VirtualBox 내부 실습용 사설 주소다.

## 폴더 구성

```text
VMS-hw/
├── README.md                        # 전체 목차와 실습 환경 (이 문서)
├── PROGRESS.md                      # 현재 진행 위치와 다음 단계
├── 01-os-install-network-test/      # 과제 1 (README = 요약, DETAILS = 상세)
├── 02-network-bonding/              # 과제 2
├── 03-application-ha/               # 과제 3
├── 04-windows11-optimization/       # 과제 4
├── 05-network-basics/               # 과제 5
└── 06-shell-script/                 # 과제 6
```
