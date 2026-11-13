# 5 · L2 · L3 · L4, 라우팅, 포트포워딩 · 개념 정리

> 개념을 정리한 문서입니다. 과제 1~3에서 이미 만난 장면과 연결해 두었습니다. 요약은 [README.md](./README.md)에 있습니다.

## 한눈에 보기

| 계층 | 보는 주소 | 대표 장비 · 기능 | 택배 비유 | 우리 실습에서 만난 곳 |
| --- | --- | --- | --- | --- |
| **L2** 데이터링크 | **MAC 주소** (`08:00:27:…`) | 스위치, 브리지, bond | 같은 동네 안에서 **집 앞 문패**를 보고 배달 | 과제 2 bond, `fail_over_mac`, ARP, gratuitous ARP |
| **L3** 네트워크 | **IP 주소** (`192.168.56.11`) | 라우터, L3 스위치 | **다른 동네**로 보낼 때 주소(시·구)를 보고 경로 선택 | 과제 1 기본 경로, 과제 2 7-A 기본 경로 중복 |
| **L4** 전송 | **포트 번호** (80, 3306) + TCP/UDP | L4 스위치, 로드밸런서, 방화벽 | 같은 건물 안 **몇 호실**(어느 서비스)로 갈지 | 과제 3 http(80), mysql(3306) 방화벽 허용 |

**계층이 올라갈수록 더 많은 정보를 보고 판단합니다.** L2 스위치는 MAC만 보고, 라우터는 IP까지 보고, L4 장비는 포트까지 봅니다.

## L2: 같은 네트워크 안의 전달

- **스위치**는 포트마다 연결된 MAC 주소를 표(MAC 테이블)로 기억했다가, 목적지 MAC이 있는 포트로만 보냅니다.
- **ARP**는 "IP 192.168.56.12의 MAC이 뭐예요?"라고 동네 전체에 묻는 방송입니다. 답을 받으면 ARP 테이블(`ip neigh`)에 적어 둡니다.
- **gratuitous ARP**는 묻지 않았는데 "이 IP는 이제 내 MAC으로 와"라고 먼저 알리는 방송입니다.
  - 과제 2: bond 활성 포트가 바뀔 때
  - 과제 3: Keepalived VIP가 다른 서버로 넘어갈 때

**과제 2에서 배운 L2 장애:** `fail_over_mac=none`에서 bond MAC이 대기 포트의 MAC으로 잡혀, 가상 스위치가 프레임을 대기 포트로 보내 버려졌습니다. **L2 문제는 IP가 맞아도 통신이 안 됩니다.** 그래서 `ip neigh`에서 `FAILED`가 보였습니다.

## L3: 다른 네트워크로 보내는 길, 라우팅

**라우팅 테이블 읽기** (`ip route`)
```
default via 10.0.2.2 dev enp0s3 metric 100        ← 모르는 곳은 전부 여기로 (기본 경로)
10.10.10.0/24 dev bond0 proto kernel              ← 10.10.10.x는 bond0로 직접
192.168.56.0/24 dev enp0s8 proto kernel           ← 192.168.56.x는 enp0s8로 직접
```

**경로를 고르는 규칙**
1. **가장 구체적인 경로가 이긴다(longest prefix match).** `10.10.10.13`은 `/24` 경로가 `default(/0)`보다 구체적이라 bond0로 갑니다.
2. 같은 크기의 경로가 여럿이면 **metric이 작은 쪽**이 이깁니다.
3. 실제로 어느 길로 나가는지는 `ip route get <목적지>`로 바로 확인합니다.

**과제 2 7-A에서 겪은 것:** 내부망 bond1에 게이트웨이를 넣었더니 기본 경로가 두 개가 됐고, metric이 더 작은 bond1 쪽으로 인터넷 트래픽이 빠져 통신이 끊겼습니다. **기본 경로는 하나만**이 원칙입니다.

**라우터가 되려면:** 리눅스 서버도 `net.ipv4.ip_forward=1`을 켜면 한 NIC로 들어온 패킷을 다른 NIC로 넘겨 주는 라우터가 됩니다.

## L4: 포트와 TCP · UDP

| | TCP | UDP |
| --- | --- | --- |
| 연결 | 먼저 연결을 맺음(3-way handshake) | 연결 없이 바로 보냄 |
| 신뢰성 | 순서 보장, 손실 시 재전송 | 보장 안 함 |
| 예 | 웹(80, 443), SSH(22), MariaDB(3306) | DNS(53), DHCP(67/68) |

- **포트**는 한 서버 안에서 어느 프로그램이 받을지 정하는 번호입니다. IP가 건물 주소라면 포트는 호실입니다.
- **L4 스위치·로드밸런서**는 IP와 포트를 보고 여러 서버에 나눠 보냅니다. 과제 3의 Keepalived는 "한 서버가 VIP를 갖는" 방식이고, 여기에 LVS(L4 로드밸런싱)를 붙이면 여러 서버에 동시에 나눠 보낼 수 있습니다.
- **방화벽**도 L4 정보를 봅니다. 과제 3에서 `firewall-cmd --add-service=http`(80/tcp), `mysql`(3306/tcp)을 연 것이 그 예입니다.
- VRRP는 TCP도 UDP도 아니라 **IP 프로토콜 번호 112**를 쓰는 별도 프로토콜이라 `rich-rule ... protocol value="vrrp"`로 따로 열었습니다.

## 포워딩: IP 포워딩과 포트포워딩

| 용어 | 뜻 | 예 |
| --- | --- | --- |
| **IP 포워딩** | 서버가 받은 패킷을 다른 네트워크로 넘겨 주는 라우터 기능 | `sysctl net.ipv4.ip_forward=1` |
| **NAT (SNAT, 마스커레이드)** | 내부 주소를 바깥 주소로 **바꿔서 내보냄** | 집 공유기, VirtualBox NAT(VM의 10.0.2.15가 PC 주소로 바뀌어 인터넷에 나감) |
| **포트포워딩 (DNAT)** | 바깥 주소의 특정 포트로 들어온 것을 **안쪽 서버의 포트로 바꿔 넣어 줌** | 공유기에서 "외부 8080 → 내부 192.168.0.10:80" |

**택배 비유:** NAT는 회사 대표 주소로 발송하는 것이고, 포트포워딩은 대표 주소 "8080호"로 온 택배를 안쪽 "웹 서버 80호"로 넘겨 주는 안내 데스크입니다.

**리눅스 firewalld 포트포워딩 예**
```bash
firewall-cmd --add-forward-port=port=8080:proto=tcp:toport=80:toaddr=192.168.56.12
```
node1의 8080으로 들어온 요청을 node2의 80으로 넘깁니다. 다른 서버로 넘길 때는 그 영역(zone)에 마스커레이드도 켜야 응답이 제대로 돌아옵니다.

**VirtualBox에도 같은 기능이 있습니다:** NAT 어댑터의 "포트 포워딩"에서 "호스트 2222 → VM 22"로 정하면, NAT 뒤에 있는 VM에 PC에서 SSH로 들어갈 수 있습니다. 우리는 호스트 전용 네트워크를 따로 둬서 이 방법을 쓰지 않았습니다.

## 장애 장면별 확인 순서

문의가 오면 "어디까지는 되는가"를 먼저 정하고, 그 바로 위 계층부터 봅니다.

**장면 1 · ping은 되는데 웹 페이지가 안 열림 (어제까지는 됨)**
- ping(ICMP)이 가므로 L3까지는 정상입니다.
- 순서: 포트까지 가는지(`Test-NetConnection 서버IP -Port 80`) → 서버에서 서비스와 포트(`systemctl status nginx`, `ss -tlnp | grep :80`) → 방화벽(`firewall-cmd --list-all`)
- "어제까지 됐다" = 오늘 무언가 바뀜. 재부팅(`--permanent` 없이 넣은 설정이 사라짐), 업데이트, 방화벽 정책 변경, 인증서 만료를 먼저 묻습니다.

**장면 2 · 같은 대역인데 ping이 안 됨**
- 같은 동네라 라우터와는 상관없습니다. L1 · L2를 봅니다.
- 링크(`ip -br link`) → 상대 MAC이 `FAILED`인지(`ip neigh`) → ARP 요청 · 응답(`tcpdump -eni any arp`) → 상대 방화벽의 ICMP 차단 여부
- 과제 2의 `fail_over_mac=none` 장애가 이 경우였습니다.

**장면 3 · 내부망은 되는데 인터넷(다른 대역)만 안 됨**
- L3 경로를 봅니다. `default`가 두 개인지, `ip route get 8.8.8.8`이 어느 NIC로 나가는지.
- 게이트웨이 → 바깥 IP → 도메인 순서로 ping. IP는 되는데 도메인만 안 되면 DNS(`/etc/resolv.conf`, `nslookup`)입니다.
- 과제 2 7-A(기본 경로 중복)가 이 경우였습니다.

**장면 4 · 포트포워딩을 걸었는데 밖에서 안 들어옴**
1. 규칙이 들어갔는지: `firewall-cmd --list-forward-ports`
2. 다른 서버로 넘기면 `ip_forward=1`과 마스커레이드가 켜져 있는지
3. 안쪽 서버가 그 포트에서 듣고, 안쪽 방화벽도 열려 있는지
4. 응답이 같은 길로 돌아오는지: `tcpdump -ni any port 80`을 양쪽에서

## 명령어 모음 (Linux · Windows)

| 확인할 것 | 계층 | Linux (Rocky) | Windows (PowerShell) |
| --- | --- | --- | --- |
| 링크 상태 | L1 | `ip -br link` | `Get-NetAdapter` |
| 내 IP | L3 | `ip -br a` | `Get-NetIPAddress` / `ipconfig` |
| 상대 MAC(ARP 표) | L2 | `ip neigh` | `arp -a` / `Get-NetNeighbor` |
| 라우팅 표 | L3 | `ip route` | `route print` / `Get-NetRoute` |
| 이 목적지는 어느 길로 | L3 | `ip route get 8.8.8.8` | `Find-NetRoute -RemoteIPAddress 8.8.8.8` |
| 가는 길 추적 | L3 | `tracepath` / `traceroute` | `tracert` |
| 듣고 있는 포트 | L4 | `ss -tlnp` | `Get-NetTCPConnection -State Listen` |
| 상대 포트까지 가나 | L4 | `curl -v http://IP` / `nc -zv IP 80` | `Test-NetConnection IP -Port 80` |
| 방화벽 규칙 | L4 | `firewall-cmd --list-all` | `Get-NetFirewallRule -Enabled True` |
| DNS | L7 | `cat /etc/resolv.conf`, `nslookup` | `Resolve-DnsName` |
| 패킷 직접 보기 | 전체 | `tcpdump -eni any` | Wireshark / `pktmon` |
| IP 포워딩 | L3 | `sysctl net.ipv4.ip_forward` | - |

## 사수가 물어볼 만한 질문

<details>
<summary>Q1. L2 스위치와 L3 스위치의 차이는?</summary>

L2 스위치는 MAC 주소만 보고 같은 네트워크 안에서 전달합니다. L3 스위치는 IP까지 보고 서로 다른 네트워크(VLAN) 사이를 라우팅할 수 있습니다.
</details>

<details>
<summary>Q2. ping은 되는데 웹 접속이 안 되면 어느 계층을 의심하나요?</summary>

ping(ICMP)이 되면 L3까지는 정상입니다. L4 이상을 봅니다. 서비스가 그 포트에서 듣고 있는지(`ss -tlnp`), 방화벽이 그 포트를 막는지(`firewall-cmd --list-all`)를 확인합니다.
</details>

<details>
<summary>Q3. IP는 맞는데 같은 대역끼리 통신이 안 되면?</summary>

L2를 의심합니다. `ip neigh`로 상대 MAC을 받아 왔는지(`FAILED`인지), `tcpdump -eni any`로 패킷이 어느 인터페이스로 들어오는지 봅니다. 과제 2의 fail_over_mac 장애가 이 경우였습니다.
</details>

<details>
<summary>Q4. 라우팅 테이블에 경로가 여러 개면 무엇을 고르나요?</summary>

가장 구체적인(접두사가 긴) 경로를 먼저 고르고, 같으면 metric이 작은 쪽을 고릅니다. 실제 선택은 `ip route get <목적지>`로 확인합니다.
</details>

<details>
<summary>Q5. NAT와 포트포워딩의 차이는?</summary>

NAT(SNAT)는 안에서 밖으로 나갈 때 출발 주소를 바꾸는 것이고, 포트포워딩(DNAT)은 밖에서 안으로 들어올 때 목적지 주소와 포트를 안쪽 서버로 바꾸는 것입니다.
</details>

<details>
<summary>Q6. TCP와 UDP는 언제 각각 쓰나요?</summary>

누락되면 안 되는 웹 · SSH · DB는 TCP, 빠르고 짧은 질의응답인 DNS · DHCP는 UDP를 씁니다.
</details>

<details>
<summary>Q7. gratuitous ARP는 언제 나가나요?</summary>

VIP가 다른 서버로 넘어가거나 bond 활성 포트가 바뀔 때, 주변 장비의 ARP 표를 바로 고치려고 보냅니다.
</details>
