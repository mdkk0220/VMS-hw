# 2 · Bonding 개념 정리

> 과제 2-① "네트워크 bonding 구성 종류 확인"에 해당하는 개념 정리.
> 실습 기록은 [README.md](./README.md)(요약)와 [DETAILS.md](./DETAILS.md)(상세)에 있다.

## 1. Bonding이란

**NIC 여러 개를 묶어서 하나의 가상 NIC(`bond0`)처럼 쓰는 기능**이다.

카페에 비유하면 **출입문을 두 개 두는 것**이다. 손님 입장에서는 주소가 하나(가게 하나)지만, 한쪽 문이 고장 나면 다른 문으로 드나들 수 있다. 랜카드 · 케이블 · 스위치 포트 중 하나가 고장 나도 서버 통신이 끊기지 않게 하는 것이 목적이다.

이중화는 층마다 따로 한다. bonding은 그중 **가장 아래층(네트워크 연결)**의 이중화다.

| 고장 나는 것 | 대비책 | 과제 |
|---|---|---|
| 랜카드 · 케이블 · 스위치 포트 | **bonding** | 2 |
| 웹 서버 한 대 | Keepalived + VIP | 3 |
| DB 서버 한 대 | Replication · Galera | 3 |
| 데이터 자체 (실수 삭제 · 랜섬웨어) | 백업 | 6 |

## 2. 실습에서 만들 구조

```text
node1
└── bond0  (10.10.10.11, mode=active-backup)   ← IP는 여기에만
    ├── enp0s9   active  (평소 사용)
    └── enp0s10  backup  (장애 시 전환)
          │
          │   내부 네트워크 intnet-bond (가상 스위치)
          │
node2
└── bond0  (10.10.10.12, mode=active-backup)   ← IP는 여기에만
    ├── enp0s9   active  (평소 사용)
    └── enp0s10  backup  (장애 시 전환)
```

- 기존 NIC(enp0s3 NAT, enp0s8 호스트 전용)는 **그대로 둔다.** bonding 전용 NIC 두 개(enp0s9, enp0s10)를 새로 추가해서 묶는다.
- SSH에 쓰는 enp0s8을 건드리지 않으므로, bonding 설정이 꼬여도 접속은 유지된다.

## 3. 꼭 알아야 할 용어

| 용어 | 카페 비유 | 실제 뜻 |
|---|---|---|
| **bond (master)** | 가게 간판 (주소는 하나) | 묶은 결과물인 가상 NIC. **IP는 여기에만** 붙인다 |
| **slave / port** | 실제 출입문 | 묶이는 물리 NIC (enp0s9, enp0s10). 자기 IP가 없다 |
| **active / backup** | 지금 여는 문 / 잠가 둔 예비 문 | active-backup 모드에서 실제로 쓰는 NIC와 대기하는 NIC |
| **miimon** | 문지기가 몇 초마다 "문 멀쩡해?" 확인 | 링크 상태 점검 주기(ms). `miimon=100` → 0.1초마다 확인 |
| **failover** | 1번 문 고장 → 2번 문 개방 | active NIC가 죽으면 backup이 자동으로 이어받는 것 |
| **primary** | "평소엔 1번 문" 규칙 | 평소에 active로 쓸 NIC 지정. 복구되면 다시 돌아온다 |

## 4. Bonding 모드 7가지

| mode | 이름 | 이중화 | 속도↑ | 스위치 |
|---|---|---|---|---|
| 0 | balance-rr | O | O | 설정 |
| **1** | **active-backup** | **O** | X | **불필요** |
| 2 | balance-xor | O | O | 설정 |
| 3 | broadcast | O | X | 설정 |
| 4 | 802.3ad (LACP) | O | O | **LACP** |
| 5 | balance-tlb | O | 송신만 | 불필요 |
| 6 | balance-alb | O | O | 불필요 |

카페 비유 (문 두 개 = 포트 두 개)

- **balance-rr:** 손님을 1번 문, 2번 문으로 번갈아 들여보냄
- **active-backup:** 1번 문만 열고, 고장 나면 2번 문을 엶
- **balance-xor:** 손님 주소에 따라 정해진 문으로만 들여보냄
- **broadcast:** 모든 손님을 두 문으로 동시에 들여보냄 (중복)
- **802.3ad (LACP):** 건물 관리인(스위치)과 협의해서 두 문을 함께 운영
- **balance-tlb:** 나가는 손님만 두 문으로 나눔
- **balance-alb:** 나가고 들어오는 손님 모두 두 문으로 나눔

**면접용 한 줄 정리**

> 스위치 설정 없이 안전하게 하려면 **mode 1(active-backup)**, 스위치가 LACP를 지원하고 대역폭도 늘려야 하면 **mode 4(802.3ad)**.

## 5. 왜 active-backup인가

1. **스위치 쪽 설정이 필요 없다.** 고객사 서버를 구축할 때 스위치는 다른 업체나 담당자가 관리하는 경우가 많다. mode 1은 서버 쪽 설정만으로 끝난다.
2. **동작이 단순해서 장애 원인을 찾기 쉽다.** 항상 한 NIC만 쓰니 "지금 어느 NIC로 통신 중인가"가 명확하다.
3. **VirtualBox 가상 스위치는 LACP를 지원하지 않는다.** 실습 환경에서 제대로 검증할 수 있는 모드가 mode 1이다.
4. 과제 문구도 **"Active-Backup 구성"**으로 정해져 있다.

> **참고: teaming** — RHEL/Rocky 7 · 8에는 bonding과 비슷한 teaming(teamd)이 있었다. 9에서 deprecated(폐기 예정)되어 지금은 bonding이 표준이다. 8.x 고객사에서 teaming 설정을 만날 수도 있으니 이름은 기억해 둔다.

## 6. 스스로 점검

실습 전에 답해 보고, 장애 테스트에서 직접 확인한다.

- [ ] bond0에 IP를 붙이고, enp0s9 · enp0s10에는 IP를 안 붙이는 이유는?
- [ ] active-backup에서 enp0s9 케이블을 뽑으면 무슨 일이 일어나고, ping은 몇 개쯤 빠질까?
- [ ] enp0s9를 다시 연결하면 active는 어느 NIC로 돌아갈까?
- [ ] mode 4를 쓰려면 서버 말고 어디에 무엇을 설정해야 할까?

<details>
<summary>답 보기 (실습 후 확인용)</summary>

- **IP 위치:** 바깥에서 보이는 주소는 하나여야 한다. NIC마다 IP가 있으면 한 NIC가 죽을 때 그 IP도 같이 사라진다. bond0에 IP를 두면 어떤 NIC가 살아 있든 같은 IP로 통신된다.
- **케이블 해제:** miimon이 링크 끊김을 감지하면 enp0s10이 active로 바뀐다. 감지까지 최대 0.1초, 상대방이 새 경로를 배우는 시간을 더해 ping은 0~2개 정도 빠지는 것이 보통이다. 정확한 값은 실습에서 측정한다.
- **복구 후:** `primary=enp0s9`를 지정했다면 enp0s9가 다시 active가 된다. 지정하지 않았다면 enp0s10이 계속 active로 남는다.
- **mode 4:** 서버와 연결된 **스위치 포트들을 LACP 포트 채널(EtherChannel)로 묶는 설정**이 필요하다. 서버만 mode 4로 바꾸면 묶이지 않는다.

</details>

## 7. 한 문단 설명

bonding은 NIC 여러 개를 하나의 논리 인터페이스로 묶는 기능이다. 모드는 0~6까지 있고, 스위치 설정 없이 장애 대비가 되는 mode 1(active-backup)을 가장 많이 쓴다. 대역폭까지 합치려면 스위치 LACP와 함께 mode 4를 쓴다.
