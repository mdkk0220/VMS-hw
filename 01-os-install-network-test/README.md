# 1 · OS(Rocky Linux 9.x & 8.10) 설치 및 외부 통신 테스트

> 명령어와 출력까지 담은 상세 기록은 [DETAILS.md](./DETAILS.md)에 있습니다.

## 한 줄 요약
VirtualBox에 **Rocky 9.8(node1)과 8.10(node3)**을 설치했습니다. 인터넷 통신, 내 PC와의 SSH, VM끼리의 통신까지 모두 확인했고, 진행 중에 생긴 장애 5개를 원인을 찾아 해결했습니다.

---

## 1. 과제 요구사항과 결과

| 요구사항 | 결과 |
| --- | --- |
| 가상화 환경에서 Rocky Linux 9.x 설치 | ✅ node1, Rocky 9.8 |
| 가상화 환경에서 Rocky Linux 8.10 설치 | ✅ node3, Rocky 8.10 |
| 외부 통신까지 연결 테스트 | ✅ 게이트웨이, 인터넷, DNS, HTTPS, 패키지 저장소 모두 정상 |

---

## 2. 실습 환경

| 구분 | node1 | node3 |
| --- | --- | --- |
| OS / 커널 | Rocky 9.8 / 5.14 | Rocky 8.10 / 4.18 |
| 사양 | 2 vCPU, 2 GB, 20 GB | 같음 |
| NIC 1 (NAT, 인터넷용) | enp0s3 10.0.2.15 (DHCP) | enp0s3 10.0.2.15 (DHCP) |
| NIC 2 (호스트 전용, 내부 통신용) | enp0s8 **192.168.56.11 (고정)** | enp0s8 **192.168.56.13 (고정)** |

- 두 VM의 NAT IP가 같아도 충돌하지 않습니다. VirtualBox가 NAT 네트워크를 **VM마다 따로** 만들기 때문입니다.
- 대신 NAT로는 VM끼리 통신할 수 없어서, **호스트 전용 네트워크**를 내부 통신용으로 추가했습니다.

---

## 3. 수행한 작업 (순서대로)

| # | 작업 | 확인 방법 | 결과 |
| --- | --- | --- | --- |
| 1 | ISO 무결성 확인 | `Get-FileHash`와 공식 CHECKSUM 비교 | 두 ISO 모두 일치 |
| 2 | Minimal Install로 설치 | `cat /etc/rocky-release` | 9.8 / 8.10 |
| 3 | 호스트 전용 NIC 고정 IP | `nmcli con mod … ipv4.method manual` | .11 / .13 |
| 4 | 재부팅 후 확인 | `reboot` → `ip -br a` | IP 유지, autoconnect yes |
| 5 | 통신 사다리 확인 | 아래 표 | 전부 성공 |
| 6 | 업데이트 | `dnf -y update` | 완료, 새 커널 설치 |
| 7 | SSH 접속 | 내 PC → node1, node1 → node3 | 성공 |
| 8 | DNS 장애 실험 | DHCP DNS 무시 → 증상 확인 → 복구 | 재현과 복구 성공 |

**통신 사다리 (node1 기준)**

| 대상 | 의미 | 결과 |
| --- | --- | --- |
| `10.0.2.2` | NAT 게이트웨이 (1홉) | 손실 0% |
| `8.8.8.8` | 인터넷 IP (라우팅, NAT) | 손실 0% |
| `google.com` | DNS 이름 해석 | 손실 0% |
| `curl -I https://rockylinux.org` | HTTPS 응답 (443번 포트) | `HTTP/2 200` |
| `192.168.56.11` (node3 → node1) | VM끼리 통신 | 손실 0%, 약 0.65 ms |

---

## 4. 직접 확인한 8.10과 9.8의 차이

| 항목 | Rocky 8.10 | Rocky 9.8 |
| --- | --- | --- |
| 커널 | 4.18 | 5.14 |
| 네트워크 설정 파일 | `ifcfg-*` | `*.nmconnection` |
| 기본 설치 유형 | Server | Minimal |
| 두 번째 NIC | autoconnect `no` (부팅 후 꺼져 있음) | 정상 |
| nmcli 명령 | 두 버전 모두 동일하게 동작 | 두 버전 모두 동일하게 동작 |

설정 파일 위치: 8.10은 `/etc/sysconfig/network-scripts/`, 9.8은 `/etc/NetworkManager/system-connections/`. 두 번째 NIC는 설치 직후 상태입니다.

---

## 5. 겪은 장애와 해결

| # | 증상 | 원인 | 해결 |
| --- | --- | --- | --- |
| 1 | VM 생성 실패 ("디스크가 이미 존재함") | 첫 시도에서 디스크 파일만 남음 | 미디어 관리자에서 제거, 폴더 삭제 후 재생성 |
| 2 | 마우스가 VM에서 빠져나오지 않음 | 한국어 키보드라 오른쪽 Ctrl(호스트 키)이 없음 | 포인팅 장치를 USB 태블릿으로 변경 |
| 3 | node1 → 내 PC ping 실패 | Windows 방화벽이 ICMP(ping)를 차단 | SSH가 정상이라 경로 문제가 아님을 확인 |
| 4 | node3 재부팅 후 enp0s8 비활성 | 설치 시 autoconnect가 `no`로 저장됨 | `connection.autoconnect yes` 설정 |
| 5 | **node1이 node3 이름과 IP로 바뀌어 IP 충돌** | node3용 명령을 node1에서 실행 | SSH 지문, MAC, UUID로 서버를 식별하고 UUID로 중복 연결 삭제 후 복구 |

**재발 방지:** 서버마다 IP와 OS 버전이 표시되는 색깔 프롬프트를 적용합니다. 명령을 치기 전에 프롬프트를 확인하는 습관도 들입니다.

---

## 6. 배운 핵심 개념

- **NAT와 호스트 전용 네트워크:** 인터넷으로 나가는 길과 서로 만나는 길은 따로 있습니다.
- **DHCP와 고정 IP:** 서버는 고정 IP가 원칙입니다. 설정은 nmcli connection에 저장되고, autoconnect가 꺼져 있으면 부팅 후 연결이 올라오지 않습니다.
- **통신 사다리:** 가까운 곳부터 확인하면 장애가 어느 층에서 났는지 좁힐 수 있습니다.
- **DNS:** "IP는 되는데 이름은 안 된다"면 DNS 문제입니다. `/etc/resolv.conf`는 NetworkManager가 만드는 파일이라 직접 고치지 않습니다.
- **서버 식별:** hostname과 IP는 바뀔 수 있습니다. SSH 지문, MAC, UUID는 바뀌지 않으니 이 값으로 서버를 확인합니다.

---

## 7. 한 문단 설명

> VirtualBox에서 Rocky 9.8과 8.10을 Minimal로 설치했습니다. NAT로 외부 통신을, 호스트 전용 네트워크로 내부 통신을 구성했고, 고정 IP와 재부팅 후 유지까지 확인했습니다. 게이트웨이, 외부 IP, DNS, HTTPS, dnf 순서로 통신을 점검했고, DNS 장애를 재현해서 복구했습니다. 실습 중 IP 충돌이 한 번 있었는데, SSH 호스트 키와 MAC으로 실제 서버를 식별해서 원인을 찾았습니다.

---

## 8. 남은 마무리

- [ ] node1, node3에 색깔 프롬프트 적용 후 확인
- [ ] node3 `reboot` (새 커널 적용, IP 유지 재확인)
- [ ] 스냅샷: node1 `02-과제1완료`, node3 `01-설치완료`
- [ ] (선택) Windows 방화벽 ICMP 허용 규칙으로 node1 → 내 PC ping 확인
