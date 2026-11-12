# 2 · OS(Rocky Linux 9.x & 8.10) 네트워크 이중화(Bonding) 구성 테스트 · 상세 기록

**요약: [README.md](./README.md)** · **개념: [CONCEPTS.md](./CONCEPTS.md)** (이 문서는 명령어와 출력까지 담은 상세 기록)

> NIC 두 개를 하나의 가상 인터페이스(bond)로 묶어, 랜카드나 케이블 하나가 고장 나도 통신이 유지되는지 확인한다.

`Bonding` `active-backup` `nmcli` `NetworkManager` `fail_over_mac` `miimon`

## 과제 범위
1. 네트워크 bonding 구성 종류 확인
2. bonding 1개 구성 (Active-Backup)
3. bonding 2개 구성 (Active-Backup)
4. bonding 트러블슈팅

## 진행 체크리스트
- [x] bonding 모드 0~6 비교 정리 → [CONCEPTS.md](./CONCEPTS.md)
- [x] node1 복제로 node2 생성, 복제 후 식별값 재생성
- [x] node1 · node2에 NIC 4개 추가 (내부 네트워크 intnet-bond, intnet-bk)
- [x] bond0 (active-backup) 구성 · 장애 전환 · 복구 테스트
- [x] bond0 + bond1 구성 · 서로 독립 동작 확인
- [x] 일부러 낸 장애 7-A (기본 경로 중복), 7-B (포트 이탈)
- [x] 일부러 낸 장애 7-C (miimon=0)
- [x] 재부팅 후 유지 확인 (node1 · node2 · node3)
- [x] Rocky 8.10(node3)에서도 동일하게 구성 · 장애 전환

---

## 1. 실습 환경

| 항목 | node1 | node2 |
| --- | --- | --- |
| OS | Rocky Linux 9.8 | Rocky Linux 9.8 (node1 완전 복제) |
| 관리망 enp0s8 (Host-only) | 192.168.56.11 | 192.168.56.12 |
| bond0 (intnet-bond) | 10.10.10.11/24 · enp0s9 + enp0s10 | 10.10.10.12/24 · enp0s9 + enp0s10 |
| bond1 (intnet-bk) | 10.20.20.11/24 · enp0s16 + enp0s17 | 10.20.20.12/24 · enp0s16 + enp0s17 |
| 프롬프트 색 | 초록 | 파랑 |

VirtualBox 어댑터 번호와 장치 이름 대응

| 어댑터 | 장치 | 네트워크 | 용도 |
| --- | --- | --- | --- |
| 1 | enp0s3 | NAT | 인터넷 |
| 2 | enp0s8 | Host-only | SSH 관리 |
| 3 | enp0s9 | 내부 intnet-bond | bond0 주 포트 |
| 4 | enp0s10 | 내부 intnet-bond | bond0 대기 포트 |
| 5 | enp0s16 | 내부 intnet-bk | bond1 주 포트 |
| 6 | enp0s17 | 내부 intnet-bk | bond1 대기 포트 |

내부 네트워크 어댑터는 무작위 모드(Promiscuous)를 `allow-all`로 설정했다.

### 복제 후 바꾼 값 (node2)
복제하면 아래 값이 node1과 같아지므로 모두 새로 만들었다.

| 항목 | 방법 |
| --- | --- |
| MAC 주소 | VirtualBox 복제 시 "모든 네트워크 어댑터의 새 MAC 주소 생성" |
| machine-id | `rm -f /etc/machine-id && systemd-machine-id-setup` |
| SSH 호스트 키 | `rm -f /etc/ssh/ssh_host_* && ssh-keygen -A` |
| hostname, IP | `hostnamectl set-hostname node2`, enp0s8을 .12로 변경 |

> connection UUID는 복제해도 그대로 복사되므로 **서버 식별값으로 쓸 수 없다.** 서버 확인은 MAC, SSH 호스트 키 지문, machine-id로 한다.

---

## 2. bond0 구성 (bond 1개)

```bash
nmcli con add type bond con-name bond0 ifname bond0 \
  bond.options "mode=active-backup,miimon=100,primary=enp0s9,fail_over_mac=active"
nmcli con mod bond0 ipv4.method manual ipv4.addresses 10.10.10.11/24 ipv6.method disabled
nmcli con add type ethernet con-name bond0-p1 ifname enp0s9  master bond0 slave-type bond
nmcli con add type ethernet con-name bond0-p2 ifname enp0s10 master bond0 slave-type bond
nmcli con up bond0
```
(node2는 주소만 10.10.10.12/24)

| 옵션 | 의미 |
| --- | --- |
| `mode=active-backup` | 한 포트만 사용하고 나머지는 대기 |
| `miimon=100` | 0.1초마다 포트 링크 상태 확인 |
| `primary=enp0s9` | 살아 있으면 enp0s9를 우선 사용 |
| `fail_over_mac=active` | bond MAC을 현재 활성 포트의 MAC으로 따라가게 함 (VirtualBox 내부 네트워크에서 필수, 장애 2 참고) |

### 장애 전환 테스트
node2에서 `ping -D -O 10.10.10.11`을 걸어 두고 PC에서 node1 어댑터 3 링크를 끊고 다시 연결했다.

```powershell
& "C:\Program Files\Oracle\VirtualBox\VBoxManage.exe" controlvm node1 setlinkstate3 off
& "C:\Program Files\Oracle\VirtualBox\VBoxManage.exe" controlvm node1 setlinkstate3 on
```

| 동작 | 활성 포트 | ping 손실 |
| --- | --- | --- |
| 어댑터 3 끊기 (페일오버) | enp0s9 → enp0s10 | **1 / 210** |
| 어댑터 3 연결 (페일백) | enp0s10 → enp0s9 (primary) | **0** |

`/proc/net/bonding/bond0`의 `Link Failure Count`가 1 증가한 것도 확인했다.

---

## 3. bond1 추가 (bond 2개)

```bash
nmcli con add type bond con-name bond1 ifname bond1 \
  bond.options "mode=active-backup,miimon=100,primary=enp0s16,fail_over_mac=active"
nmcli con mod bond1 ipv4.method manual ipv4.addresses 10.20.20.11/24 ipv6.method disabled
nmcli con add type ethernet con-name bond1-p1 ifname enp0s16 master bond1 slave-type bond
nmcli con add type ethernet con-name bond1-p2 ifname enp0s17 master bond1 slave-type bond
```

- 두 bond는 서로 다른 네트워크(10.10.10.0/24, 10.20.20.0/24)이므로 게이트웨이를 넣지 않는다.
- 기본 경로(default route)는 NAT(enp0s3)의 것 하나만 유지한다.

### 독립성 테스트
node2에서 bond0, bond1 양쪽으로 동시에 ping을 걸고, node1 어댑터 5(bond1 활성 포트)만 끊었다.

| 대상 | ping 손실 |
| --- | --- |
| bond1 (10.20.20.11) | **2 / 40** (페일오버 순간) |
| bond0 (10.10.10.11) | **0 / 40** |

한 bond의 장애가 다른 bond에 영향을 주지 않음을 확인했다.

스냅샷: `과제2-시작전`, `과제2-bond0완료`, `과제2-bond1완료` (node1, node2 모두)

---

## 4. 트러블슈팅

### 장애 1 · 자동 생성 "Wired connection" 프로파일이 포트를 가로챔 (실제 발생)
| 항목 | 내용 |
| --- | --- |
| 증상 | 어댑터를 추가하자 NetworkManager가 `Wired connection 1` 같은 프로파일을 자동으로 만들어 새 NIC에 연결함. bond 포트 프로파일이 붙지 못함 |
| 원인 | 설정 파일이 없는 NIC에는 NetworkManager가 기본 DHCP 프로파일을 만든다. 이 프로파일은 `/run`(메모리)에 있어 재부팅하면 다시 생긴다 |
| 조치 | 자동 프로파일 삭제 후 bond 포트 프로파일 활성화. 삭제한 NIC는 `no-auto-default`에 기록되어 다시 생기지 않음 |
| 확인 | `nmcli -f NAME,DEVICE con show` 에서 enp0s9 등이 bondN-pN에 연결됨 |

### 장애 2 · bond0 ping 실패, ARP FAILED (실제 발생)
| 항목 | 내용 |
| --- | --- |
| 증상 | bond0 UP, IP 정상인데 node1 ↔ node2 ping 100% 손실. `ip neigh`에 상대가 `FAILED` |
| 확인 | `tcpdump -eni any icmp` 결과 node2로 오는 ICMP가 **대기 포트 enp0s10으로만** 들어옴 |
| 원인 | 기본값 `fail_over_mac=none`이면 모든 포트가 첫 번째로 붙은 포트의 MAC을 같이 쓴다. node2는 enp0s10이 먼저 붙어 bond MAC이 enp0s10 것이 되었고, VirtualBox 내부 네트워크는 그 MAC의 원래 어댑터(대기 포트)로 프레임을 보냈다. active-backup은 대기 포트로 들어온 패킷을 버린다 |
| 조치 | 양쪽 모두 `fail_over_mac=active` 추가 후 `nmcli con up bond0` |
| 확인 | ping 정상, 장애 전환 테스트 통과 |
| 재발 방지 | 가상화 환경(MAC 기반 전달)에서는 active-backup에 `fail_over_mac=active`를 기본으로 넣는다 |

### 장애 3 · 설정 직후 상태 확인으로 생긴 오판 (실제 발생)
| 항목 | 내용 |
| --- | --- |
| 증상 | `nmcli con up` 직후 bond0가 `connecting`, 주소가 `fe80::`만 보임 |
| 원인 | 설정이 틀린 것이 아니라 활성화가 끝나기 전에 확인했음 |
| 조치 | 약 10초 기다린 뒤 다시 확인하니 정상 |
| 재발 방지 | 변경 직후 바로 결론 내리지 말고, 몇 초 뒤 프로파일 값(`nmcli con show bond0`)과 실제 상태(`ip a`)를 따로 확인한다 |

### 7-A · 기본 경로 중복 (일부러 재현)
| 항목 | 내용 |
| --- | --- |
| 재현 | `nmcli con mod bond1 ipv4.gateway 10.20.20.1 ipv4.route-metric 50; nmcli con up bond1` |
| 증상 | `ip route`에 default가 2개. metric이 더 작은 bond1 경로가 우선되어 외부 통신이 존재하지 않는 10.20.20.1로 감 |
| 확인 | `ip route get 8.8.8.8` → `via 10.20.20.1 dev bond1` |
| 원인 | 내부 전용망에 게이트웨이를 넣어 기본 경로가 하나 더 생김 |
| 조치 | `nmcli con mod bond1 ipv4.gateway "" ipv4.route-metric -1; nmcli con up bond1` |
| 확인 | default가 NAT(enp0s3) 하나만 남고 외부 통신 정상 |
| 재발 방지 | 기본 경로는 서버당 하나. 내부망 bond에는 게이트웨이를 넣지 않는다 |

### 7-B · 포트가 조용히 빠져 이중화가 사라짐 (일부러 재현)
| 항목 | 내용 |
| --- | --- |
| 재현 | `nmcli con mod bond1-p2 connection.autoconnect no; nmcli con down bond1-p2` |
| 증상 | 평소에는 ping, `ip a`, `nmcli con show` 모두 정상으로 보임. 남은 포트(어댑터 5)를 끊자 bond1 통신이 전부 끊김 |
| 결과 | **67개 중 46개 손실**, `Destination Host Unreachable` (6-5에서 같은 동작 시 2개 손실) |
| 확인 | `grep -c "Slave Interface" /proc/net/bonding/bond1` → **1** (정상 2). 장애 중 `Currently Active Slave: None`, `bond1 DOWN <NO-CARRIER>` |
| 원인 | 포트 프로파일 하나가 내려가 있어도 bond는 남은 포트로 동작하므로 겉으로 드러나지 않음 |
| 조치 | `nmcli con mod bond1-p2 connection.autoconnect yes; nmcli con up bond1-p2` |
| 확인 | 포트 개수 2, 두 포트 모두 `MII Status: up`, AUTOCONNECT 모두 `yes` |
| 재발 방지 | 정기 점검에 포트 개수와 `Link Failure Count`를 넣는다. ping 성공만으로 정상이라고 판단하지 않는다 |

장애 중 node1 상태
```
Currently Active Slave: None
MII Status: down
MII Status: down
bond1            DOWN           08:00:27:1e:14:4e <NO-CARRIER,BROADCAST,MULTICAST,MASTER,UP>
```

### bond 정기 점검 항목
| 항목 | 명령 | 정상 값 |
| --- | --- | --- |
| 모드 | `grep "Bonding Mode" /proc/net/bonding/bondN` | `active-backup (fail_over_mac active)` |
| 포트 개수 | `grep -c "Slave Interface" /proc/net/bonding/bondN` | 2 |
| 포트 링크 | `grep "MII Status" /proc/net/bonding/bondN` | 모두 `up` |
| 감시 간격 | `grep "MII Polling" /proc/net/bonding/bondN` | 0이 아님 (100) |
| 장애 이력 | `grep "Link Failure Count" /proc/net/bonding/bondN` | 지난 점검보다 늘었으면 원인 확인 |

### 7-C · 링크 감시가 꺼져 페일오버가 일어나지 않음 (일부러 재현)
| 항목 | 내용 |
| --- | --- |
| 재현 | `nmcli con mod bond0 bond.options "mode=active-backup,miimon=0,primary=enp0s9,fail_over_mac=active"; nmcli con up bond0` 후 PC에서 `setlinkstate3 off` |
| 증상 | 대기 포트 enp0s10이 살아 있는데도 넘어가지 않음. **50개 중 26개 손실**, 링크를 다시 연결할 때까지 계속 (같은 동작을 miimon=100에서 했을 때는 1개 손실) |
| 확인 | `MII Polling Interval (ms): 0`. 커널 `carrier`는 `0`인데 bond의 enp0s9 `MII Status`는 `up`, 활성 포트도 enp0s9 그대로. dmesg에 경고 없음 |
| 원인 | 링크 감시가 꺼져 bond가 포트 상태를 다시 확인하지 않음 |
| 조치 | `nmcli con mod bond0 bond.options "mode=active-backup,miimon=100,primary=enp0s9,fail_over_mac=active"; nmcli con up bond0` |
| 확인 | miimon 100, carrier 1, 포트 2개, bond0 · bond1 ping 0% loss |
| 재발 방지 | 정기 점검에 감시 간격 추가. 장애가 의심되면 bond 상태와 `/sys/class/net/<포트>/carrier`를 비교 |

끊긴 순간 node1 상태
```
Currently Active Slave: enp0s9
MII Status: up
Slave Interface: enp0s10
MII Status: up
Slave Interface: enp0s9
MII Status: up
0                      ← cat /sys/class/net/enp0s9/carrier
```

### 재부팅 후 유지
| 서버 | 확인 | 결과 |
| --- | --- | --- |
| node1 | 부팅 10분 뒤 | bond0 · bond1 모두 primary 활성, 포트 2개, miimon 100 |
| node2 | 부팅 17분 뒤 | bond0 · bond1 포트 2개씩 |
| node3 | `reboot` 직후 | bond0 활성 enp0s9, 포트 2개, 10.10.10.13, `Wired connection` 다시 생기지 않음 |

---

## 5. Rocky 8.10(node3)에서 bond0 구성

### NIC 추가 (node3 전원 끈 상태, 스냅샷 `과제2-node3-NIC추가전` 뒤)
```powershell
VBoxManage modifyvm node3 --nic3 intnet --intnet3 intnet-bond --nicpromisc3 allow-all --cableconnected3 on
VBoxManage modifyvm node3 --nic4 intnet --intnet4 intnet-bond --nicpromisc4 allow-all --cableconnected4 on
```
| 어댑터 | 장치 | MAC | 용도 |
| --- | --- | --- | --- |
| 3 | enp0s9 | 08:00:27:72:f3:6c | bond0 주 포트 |
| 4 | enp0s10 | 08:00:27:2b:fa:39 | bond0 대기 포트 |

### 자동 프로파일 정리
9.8과 같이 새 NIC에 `Wired connection 1, 2`가 자동으로 생겼다. intnet-bond에는 DHCP 서버가 없어 연결되지 않은 상태(DEVICE `--`)였지만 `AUTOCONNECT yes`라 UUID로 지웠다. 8.10에서도 이 자동 프로파일은 `/run/NetworkManager/system-connections/`에 keyfile(`.nmconnection`) 형식으로 만들어진다. 직접 만든 프로파일만 ifcfg로 저장된다.

### bond0 구성 (명령은 9.8과 같음)
```bash
nmcli con add type bond con-name bond0 ifname bond0 bond.options "mode=active-backup,miimon=100,primary=enp0s9,fail_over_mac=active"
nmcli con mod bond0 ipv4.method manual ipv4.addresses 10.10.10.13/24 ipv6.method disabled
nmcli con add type ethernet con-name bond0-p1 ifname enp0s9 master bond0 slave-type bond
nmcli con add type ethernet con-name bond0-p2 ifname enp0s10 master bond0 slave-type bond
nmcli con up bond0
```

생성된 파일 `/etc/sysconfig/network-scripts/ifcfg-bond0` (일부)
```
BONDING_OPTS="mode=active-backup fail_over_mac=active miimon=100 primary=enp0s9"
TYPE=Bond
BONDING_MASTER=yes
BOOTPROTO=none
DEFROUTE=yes
ONBOOT=yes
IPADDR=10.10.10.13
PREFIX=24
```
`DEFROUTE=yes`지만 게이트웨이가 없어 기본 경로는 생기지 않는다. 나중에 `GATEWAY=`를 넣으면 7-A와 같은 문제가 생길 수 있다.

### 9.8과 8.10 비교
| 항목 | 9.8 (node1) | 8.10 (node3) |
| --- | --- | --- |
| 커널 | 5.14 | 4.18 |
| 명령 | 같음 | 같음 |
| 저장 파일 | `/etc/NetworkManager/system-connections/bond0.nmconnection` | `/etc/sysconfig/network-scripts/ifcfg-bond0` |
| bond 옵션 | `[bond]` 섹션에 한 줄씩 | `BONDING_OPTS="…"` 한 줄, 공백 구분 |
| 부팅 시 자동 연결 | `autoconnect` | `ONBOOT=yes` |
| 활성화 메시지 | `controller waiting for ports` | `master waiting for slaves` (NetworkManager 버전 차이, 뜻은 같음) |

### 통신과 장애 전환
- node1 → node3, node2 → node3 ping 0% loss
- node1에서 `ping -D -O 10.10.10.13`을 걸어 두고 node3 어댑터 3을 끊었다 연결: **101개 중 1개 손실**

```
764.8  bond0: (slave enp0s9): link status definitely down, disabling slave
764.8  bond0: (slave enp0s10): making interface the new active one
787.7  bond0: (slave enp0s9): link status definitely up, 1000 Mbps full duplex
787.7  bond0: (slave enp0s9): making interface the new active one
```
enp0s9 `Link Failure Count: 1`, 복구 후 primary인 enp0s9로 돌아왔다. 9.8과 동작 · 메시지가 같다.

---

## 배운 점
- bond는 "묶었다"로 끝나지 않는다. 장애를 직접 내서 넘어가는지 봐야 이중화가 증명된다.
- 가상화 환경에서는 MAC 처리(`fail_over_mac`)가 실제 장비와 다르게 문제를 만든다. 패킷이 **어느 포트로 들어오는지**(`tcpdump -eni any`)를 보면 원인이 바로 보인다.
- 이중화가 깨져도 통신은 계속될 수 있다. 상태 파일(`/proc/net/bonding`)을 숫자로 점검해야 한다.
- 링크 감시(miimon)가 0이면 랜선이 빠져도 bond는 계속 up으로 보이고 로그도 없다. 감시 간격과 carrier를 함께 본다.
- 8.10도 nmcli 명령은 같다. 설정 위치만 다르니(`ifcfg-bond0`) 서버 OS 버전부터 확인한다.
- 기본 경로는 하나만. 문제가 생기면 `ip route get <목적지>`로 실제 나가는 길을 확인한다.

## 연결
- 이전 과제: [1 · OS 설치 및 외부 통신 테스트](../01-os-install-network-test/)
- 다음 과제: [3 · Application 이중화 · 다중화](../03-application-ha/)
