# 1 · OS(Rocky Linux 9.x & 8.10) 설치 및 외부 통신 테스트

> VirtualBox에 Rocky Linux 9.8과 8.10을 각각 설치하고, 인터넷 · 호스트 PC · VM 간 통신을 단계별로 확인했다.
> 진행 중 생긴 장애 5건을 원인부터 찾아 해결했다.

`VirtualBox` `Rocky Linux 9.8` `Rocky Linux 8.10` `nmcli` `SSH` `DNS`

**한눈에 보기: [SUMMARY.md](./SUMMARY.md)** (표로 정리한 요약본)

## 목표
- 가상화 환경에 Rocky Linux 9.x와 8.10을 설치한다.
- 외부(인터넷) 통신과 내부(호스트 PC · VM 간) 통신을 모두 확인한다.
- 서버답게 고정 IP를 쓰고, 재부팅 후에도 설정이 유지되는지 확인한다.

## 환경

| 항목 | node1 | node3 |
|---|---|---|
| OS / 커널 | Rocky Linux 9.8 / 5.14 | Rocky Linux 8.10 / 4.18 |
| 사양 | 2 vCPU · 2 GB · 20 GB | 동일 |
| 어댑터 1 (NAT) | enp0s3 · 10.0.2.15 (DHCP) | enp0s3 · 10.0.2.15 (DHCP) |
| 어댑터 2 (호스트 전용) | enp0s8 · 192.168.56.11 (고정) | enp0s8 · 192.168.56.13 (고정) |
| 설치 옵션 | Minimal Install · 자동 파티션(LVM) | Minimal Install · 자동 파티션 · KDUMP 끔 |

두 VM의 NAT IP가 같아도 충돌하지 않는다. VirtualBox NAT는 VM마다 별도의 네트워크를 만들기 때문이다. 대신 NAT로는 VM끼리 통신할 수 없어서 호스트 전용 어댑터를 추가했다.

## 실습 과정

### 1. 설치 이미지 무결성 확인
받은 ISO가 깨지지 않았는지 공식 SHA256 체크섬과 비교했다.

```powershell
Get-FileHash .\Rocky-9.8-x86_64-minimal.iso -Algorithm SHA256   # 공식 CHECKSUM 값과 비교

# 8.10은 공식 CHECKSUM 파일을 받아 자동으로 비교
$c = Invoke-RestMethod https://download.rockylinux.org/pub/rocky/8/isos/x86_64/CHECKSUM
$official = ([regex]'SHA256 \(Rocky-8\.10-x86_64-minimal\.iso\) = ([0-9a-f]{64})').Match($c).Groups[1].Value
(Get-FileHash .\Rocky-8.10-x86_64-minimal.iso -Algorithm SHA256).Hash -eq $official   # True
```

두 ISO 모두 공식 값과 일치했다. 9.8의 CHECKSUM 파일에 적힌 크기는 실제 파일과 달랐지만, 무결성 판단 기준은 크기가 아니라 해시다.

### 2. VM 생성과 설치
- 무인 설치(Unattended Installation)는 끄고 설치 과정을 직접 진행했다.
- 포인팅 장치는 USB 태블릿으로 바꿨다. 마우스가 VM 창에 갇히지 않는다.
- 8.10 설치 화면은 9.8과 기본값이 달랐다. Software Selection(Server → Minimal), 시간대(New York → Seoul), NIC(기본 꺼짐 → ON)를 직접 바꿨다.

```bash
cat /etc/rocky-release   # Rocky Linux release 9.8 (Blue Onyx) / 8.10 (Green Obsidian)
uname -r                 # 5.14.0-… (9.8) / 4.18.0-… (8.10)
lsblk                    # /boot 1G + LVM(root 17G, swap 2G)
```

### 3. 호스트 전용 NIC 고정 IP
DHCP로 받은 임시 주소(.101, .102)를 서버용 고정 주소로 바꿨다.

```bash
nmcli con mod enp0s8 ipv4.method manual ipv4.addresses 192.168.56.11/24 connection.autoconnect yes
nmcli con up enp0s8                    # 변경한 설정 적용
nmcli -g ipv4.method,ipv4.addresses,connection.autoconnect con show enp0s8
# manual / 192.168.56.11/24 / yes
```

호스트 전용 NIC에는 게이트웨이를 넣지 않았다. 기본 경로는 NAT 쪽 하나만 있어야 경로가 꼬이지 않는다.

```text
default via 10.0.2.2 dev enp0s3 proto dhcp src 10.0.2.15
192.168.56.0/24 dev enp0s8 proto kernel scope link src 192.168.56.11
```

### 4. 통신 단계별 점검 (가까운 곳 → 먼 곳)
어디까지 통하는지 한 칸씩 확인했다. 막히는 칸이 장애가 난 계층을 알려 준다.

```bash
ping -c 3 10.0.2.2              # NAT 게이트웨이 (1홉)
ping -c 3 8.8.8.8               # 인터넷 IP (라우팅 · NAT)
ping -c 3 google.com            # DNS 이름 해석
curl -I https://rockylinux.org  # HTTPS 응답 (443)
dnf -y update                   # 패키지 저장소 접속 (종합 확인)
```

| 단계 | 결과 |
|---|---|
| `10.0.2.2` | 손실 0% · ttl=64 |
| `8.8.8.8` | 손실 0% · ttl=115 |
| `google.com` | 손실 0% · DNS로 IP 해석 |
| `rockylinux.org` | `HTTP/2 200` |
| `dnf update` | 완료 · 새 커널 설치 (재부팅 후 적용 확인) |

### 5. SSH 접속과 VM 간 통신
- 호스트 PC(PowerShell) → node1: 첫 접속에서 호스트 키 지문을 확인하고 `known_hosts`에 등록했다.
- node1 → node3: SSH 접속과 ping이 모두 성공했다.

```text
[root@node3 ~]# ping -c 3 192.168.56.11
3 packets transmitted, 3 received, 0% packet loss
rtt min/avg/max/mdev = 0.623/0.647/0.662/0.034 ms
```

### 6. 재부팅 후 설정 유지 확인
`reboot` 뒤 SSH로 다시 접속해 고정 IP, `autoconnect yes`, 새 커널 부팅을 확인했다.

### 7. DNS 장애 재현과 복구
"IP는 되는데 이름은 안 되는" 증상을 직접 만들어 보고 원인을 구분하는 연습을 했다.

```bash
nmcli con mod enp0s3 ipv4.ignore-auto-dns yes ipv6.ignore-auto-dns yes   # DHCP로 받은 DNS 무시
nmcli con up enp0s3
cat /etc/resolv.conf      # nameserver 줄이 모두 사라짐
ping -c 2 8.8.8.8         # 성공 → 경로는 정상
ping -c 2 google.com      # Name or service not known → DNS 문제

echo "142.250.197.238 google.com" >> /etc/hosts   # DNS 없이 /etc/hosts로 해석되는지 확인 → 성공
sed -i '/^142\.250\.197\.238 google\.com$/d' /etc/hosts   # 실험용 줄 삭제

nmcli con mod enp0s3 ipv4.ignore-auto-dns no ipv6.ignore-auto-dns no      # 복구
nmcli con up enp0s3
```

`/etc/resolv.conf`는 NetworkManager가 만드는 파일이라 직접 고치지 않고 nmcli로 바꿨다.

## 결과

| 확인한 것 | 결과 | 근거 |
|---|---|---|
| Rocky 9.8 설치 | 성공 | `cat /etc/rocky-release` |
| Rocky 8.10 설치 | 성공 | `cat /etc/rocky-release` |
| 고정 IP · 재부팅 후 유지 | 성공 | `ip -br a`, `nmcli -g …` |
| 외부 통신 (게이트웨이 · 인터넷 · DNS · HTTPS) | 성공 | ping · curl |
| 패키지 저장소 접속 | 성공 | `dnf -y update` |
| 호스트 PC → VM SSH | 성공 | PowerShell `ssh` |
| VM ↔ VM 통신 | 성공 | node3 → node1 ping, node1 → node3 SSH |
| DNS 장애 재현 · 복구 | 성공 | 위 7번 출력 |

## Rocky 8.10과 9.8 차이 (직접 확인)

| 항목 | Rocky 8.10 | Rocky 9.8 |
|---|---|---|
| 커널 | 4.18 | 5.14 |
| 네트워크 설정 파일 | `/etc/sysconfig/network-scripts/ifcfg-*` | `/etc/NetworkManager/system-connections/*.nmconnection` |
| 설치 기본 Software | Server | Minimal |
| 설치 직후 두 번째 NIC | autoconnect `no` | 정상 |
| nmcli 명령 | 동일하게 동작 | 동일하게 동작 |

설정 파일 위치는 버전마다 다르므로 `nmcli -f NAME,DEVICE,FILENAME con show`로 확인했다.

## 트러블슈팅

| 문제 | 원인 | 해결 |
|---|---|---|
| VM 생성 실패: 하드 디스크가 이미 존재 | 첫 시도에서 VM은 실패하고 디스크(`.vdi`)만 등록된 채 남음 | 미디어 관리자에서 디스크 제거, VM 폴더 삭제 후 재생성. 목록에 남은 "접근할 수 없음" 항목은 "제거만"으로 정리 |
| 마우스가 VM 창에서 빠져나오지 않음 | 한국어 키보드에 기본 호스트 키(오른쪽 Ctrl)가 없음 | 포인팅 장치를 USB 태블릿으로 변경 (`VBoxManage modifyvm <VM> --mouse usbtablet`) |
| node1 → 호스트 PC ping 100% 손실 | Windows 방화벽이 들어오는 ICMP를 차단 | 호스트 → node1 SSH는 정상이므로 경로 문제가 아님을 확인 |
| node3 재부팅 후 enp0s8 비활성(`DEVICE --`) | 설치 화면에서 ON했지만 `autoconnect no`로 저장됨 | `nmcli con mod enp0s8 … connection.autoconnect yes` |
| 엉뚱한 서버에 접속, VM 간 ping 실패 | node3용 명령을 node1에서 실행해 node1의 hostname · IP가 node3과 같아짐 (IP 충돌) | 아래 상세 |

### 상세: IP 충돌 식별과 복구
- **증상**: `ssh root@192.168.56.13`으로 접속했는데 `ping 192.168.56.11`이 `Destination Host Unreachable`로 실패했다.
- **식별**: 프롬프트 이름은 node3이었지만 바뀌지 않는 값들이 node1을 가리켰다.

| 근거 | 접속한 서버 | node1 | 실제 node3 |
|---|---|---|---|
| SSH 호스트 키 지문 | `SHA256:mqkk…` | `SHA256:mqkk…` | `SHA256:wxWT…` |
| enp0s8 MAC | `…:68:06:c5` | `…:68:06:c5` | `…:dd:9a:02` |
| 설정 파일 형식 | `.nmconnection` | `.nmconnection` | `ifcfg-*` |
| nmcli 연결 UUID | `5c9010a0-…` | `5c9010a0-…` | 다름 |

- **원인**: node3용 명령(`hostnamectl set-hostname node3`, `.13` IP 설정, `nmcli con add`)이 node1에서 실행됐다.
- **조치**: `hostnamectl set-hostname node1`으로 이름을 되돌렸다. 이름이 같은 연결 두 개 중 잘못 추가된 쪽은 **UUID로 지정해** `nmcli con delete`로 삭제했다. IP를 .11로 복구했다. 호스트 PC의 잘못된 `known_hosts` 기록은 `ssh-keygen -R 192.168.56.13`으로 지웠다.
- **검증**: node1은 `.11`과 연결 1개만 남았다. node3에 다시 접속하니 다른 지문(`wxWT…`)이 나왔고, node3 → node1 ping이 성공했다.
- **재발 방지**: 프롬프트에 서버별 색 · IP · OS 버전을 표시하고, 명령 전에 프롬프트를 확인한다.

## 배운 점
- NAT는 나가는 길, 호스트 전용 네트워크는 서로 만나는 길이다. 용도가 다르면 NIC를 나눈다.
- 서버는 고정 IP가 원칙이다. 설정이 파일로 저장되고 `autoconnect yes`여야 재부팅 후에도 살아남는다.
- 통신 점검은 가까운 곳부터 한다. "IP는 되고 이름만 안 됨"은 DNS, "ping은 안 되는데 SSH는 됨"은 ICMP 차단이다.
- hostname과 IP는 바뀔 수 있다. 서버를 식별하는 근거는 SSH 호스트 키, MAC, UUID다.
- 다음에는 변경 명령 전에 `hostname; ip -br a`로 대상 서버부터 확인한다.

## 연결
- 다음 과제: [2 · 네트워크 이중화(Bonding)](../02-network-bonding/)
- 실무에서는: 고객사 서버 구축 직후 수행하는 네트워크 점검과 같다. "재부팅하니 네트워크가 안 올라온다", "접속했더니 다른 서버다" 같은 현장 장애의 원인을 찾는 순서이기도 하다.
