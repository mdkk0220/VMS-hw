# 3 · Application(WEB · MariaDB) 단 이중화 · 다중화 구성 및 테스트 · 상세 기록

**요약: [README.md](./README.md)** (이 문서는 명령어와 출력까지 담은 상세 기록)

> 웹 서버와 DB 서버 한 대가 멈춰도 서비스가 이어지도록 이중화 · 다중화를 구성하고 장애 전환을 확인한다.

`Nginx` `Keepalived` `VRRP` `MariaDB Replication` `Galera Cluster`

## 과제 범위
1. WEB 이중화 구성 방법 확인 후 구현
2. DB 이중화 구성 방법 확인 후 구현
3. DB 다중화 구성 방법 확인 및 구현

## 진행 체크리스트
- [x] WEB 이중화: node1 · node2에 Nginx + Keepalived, VIP 192.168.56.100
- [x] WEB 장애 테스트: nginx 중지, keepalived 중지 시 VIP 전환 확인 (VM 강제 종료는 미실시)
- [x] DB 이중화: MariaDB Primary-Replica (GTID) 구성, 복제 상태 확인
- [x] DB 이중화 테스트: 복제본 직접 쓰기 → 1062 충돌 재현 · 복구 (수동 페일오버는 미실시)
- [x] DB 다중화: Galera Cluster 3노드 구성, `wsrep_cluster_size` 3 확인
- [x] DB 다중화 테스트: 노드 1대 중지 · 복귀 (전체 재기동은 절차만 정리)
- [x] Replication과 Galera 비교 정리

## 실습 과정

### 3-1 · WEB 이중화 (nginx + Keepalived)

**설치와 방화벽 (두 서버)**
```bash
dnf -y install nginx keepalived
firewall-cmd --permanent --add-service=http
firewall-cmd --permanent --add-rich-rule='rule protocol value="vrrp" accept'
firewall-cmd --reload
echo "WEB1 - node1 (192.168.56.11)" > /usr/share/nginx/html/index.html   # node2는 WEB2
systemctl enable --now nginx
```
VRRP를 막으면 두 서버가 서로를 못 들어 둘 다 VIP를 잡는다(split-brain).

**/etc/keepalived/keepalived.conf (node1)**
```
global_defs {
    router_id node1
    script_user root
    enable_script_security
}
vrrp_script chk_nginx {
    script "/usr/libexec/keepalived/check_nginx.sh"
    interval 2
    fall 2
    rise 2
    weight -30
}
vrrp_instance VI_1 {
    state MASTER            # node2: BACKUP
    interface enp0s8
    virtual_router_id 51
    priority 110            # node2: 100
    advert_int 1
    authentication {
        auth_type PASS
        auth_pass vms2026
    }
    virtual_ipaddress {
        192.168.56.100/24
    }
    track_script {
        chk_nginx
    }
}
```
`/usr/libexec/keepalived/check_nginx.sh`
```bash
#!/bin/bash
/usr/bin/systemctl is-active --quiet nginx
```
nginx가 죽으면 node1 우선순위가 110 → 80이 되어 node2(100)가 VIP를 가져간다.

**장애 전환 (내 PC에서 1초마다 VIP 호출)**
```powershell
while($true){ "$(Get-Date -f HH:mm:ss) $(curl.exe -s -m 1 http://192.168.56.100)"; Start-Sleep 1 }
```
| 동작 | 결과 | 빈 응답 |
| --- | --- | --- |
| node1 `systemctl stop nginx` | WEB1 → WEB2 | 2회 (검사 2번 실패를 기다림, 약 4초) |
| node1 `systemctl start nginx` | WEB2 → WEB1 | 0 |
| node1 `systemctl stop keepalived` | WEB1 → WEB2 | 1회 (정상 종료 시 priority 0을 알리고 나감) |
| node1 `systemctl start keepalived` | WEB2 → WEB1 | 0 |

```
(VI_1) Entering MASTER STATE
(VI_1) setting VIPs.
Sending gratuitous ARP on enp0s8 for 192.168.56.100
```

### 3-2 · DB 이중화 (MariaDB Replication, GTID)

**설치와 설정**
```bash
dnf -y install mariadb-server          # 10.5.29
firewall-cmd --permanent --add-service=mysql; firewall-cmd --reload
```
| 파일 `/etc/my.cnf.d/replication.cnf` | node1 (원본) | node2 (복제본) |
| --- | --- | --- |
| `server_id` | 1 | 2 |
| `log_bin` | `mariadb-bin` | 없음 |
| `binlog_format` | ROW | |
| `read_only` | | ON |

**복제 연결**
```sql
-- node1
CREATE USER 'repl'@'192.168.56.%' IDENTIFIED BY '********';
GRANT REPLICATION SLAVE ON *.* TO 'repl'@'192.168.56.%';
SHOW MASTER STATUS;      -- mariadb-bin.000001 / 670, gtid_binlog_pos 0-1-2
-- node2
CHANGE MASTER TO MASTER_HOST='192.168.56.11', MASTER_USER='repl',
  MASTER_PASSWORD='********', MASTER_USE_GTID=slave_pos;
START SLAVE;
```
원본 주소는 VIP가 아니라 node1 고유 IP. VIP는 웹 기준으로 node2로 넘어갈 수 있어 자기 자신을 복제하게 될 수 있다.

```
Slave_IO_Running: Yes
Slave_SQL_Running: Yes
Seconds_Behind_Master: 0
Using_Gtid: Slave_Pos
Gtid_IO_Pos: 0-1-5
```
node1에서 만든 `cafe.sales`(americano, latte)가 node2에 그대로 생겼고, `NOW()`로 넣은 시각도 같았다(ROW 형식).

### 3-3 · DB 다중화 (MariaDB Galera, 3노드)

**node3(8.10) 준비**
```bash
dnf -q module list mariadb          # 10.3 [d], 10.5, 10.11 → 기본값은 10.3
dnf -y module enable mariadb:10.5
dnf -y module install mariadb:10.5/galera
dnf -y install rsync policycoreutils-python-utils
semanage port -m -t mysqld_port_t -p tcp 4567     # 원래 tram_port_t
semanage port -a -t mysqld_port_t -p udp 4567
semanage port -a -t mysqld_port_t -p tcp 4568
semanage port -m -t mysqld_port_t -p tcp 4444     # 원래 kerberos_port_t
```
9.8은 정책에 이미 `mysqld_port_t tcp 4444, 4568, 4567`이 들어 있었다.

**공통**
```bash
mariadb -e "STOP SLAVE; RESET SLAVE ALL;"          # node2, 3-2 복제 해제
rm -f /etc/my.cnf.d/replication.cnf                # node1 · node2
dnf -y install mariadb-server-galera rsync         # node1 · node2
firewall-cmd --permanent --add-service=mysql
firewall-cmd --permanent --add-port={4567/tcp,4567/udp,4568/tcp,4444/tcp}
firewall-cmd --reload
```
| 포트 | 용도 |
| --- | --- |
| 4567 tcp/udp | 노드 간 복제 · 합의 |
| 4568 | IST (빠진 변경만 전송) |
| 4444 | SST (전체 데이터 전송, rsync) |

**/etc/my.cnf.d/galera.cnf** (노드마다 마지막 두 줄만 다름)
```
[galera]
wsrep_on=1
wsrep_provider=/usr/lib64/galera/libgalera_smm.so
wsrep_cluster_name=vms_galera
wsrep_cluster_address="gcomm://192.168.56.11,192.168.56.12,192.168.56.13"
wsrep_sst_method=rsync
binlog_format=row
default_storage_engine=InnoDB
innodb_autoinc_lock_mode=2
bind-address=0.0.0.0
wsrep_node_name=node1
wsrep_node_address=192.168.56.11
```

**시작 순서**
```bash
systemctl stop mariadb          # 세 노드
galera_new_cluster              # node1만 (bootstrap)
systemctl start mariadb         # node2
systemctl enable --now mariadb  # node3
```
node3 로그: node1에서 `./mysql`, `./performance_schema`, `./cafe`를 rsync로 받음(SST, 약 3.5MB) → `Started MariaDB 10.5 database server`. `name lookup failed`는 역방향 이름 조회 경고로 동작과 무관(`/etc/hosts`에 노드 이름을 넣으면 사라짐).

```
wsrep_local_state_comment | Synced
wsrep_incoming_addresses  | 192.168.56.11:0,192.168.56.12:0,192.168.56.13:0
wsrep_cluster_size        | 3
wsrep_cluster_status      | Primary
```

**테스트**
| 동작 | 결과 |
| --- | --- |
| node2에 `from-node2`, node3에 `from-node3` INSERT | 세 노드 모두에 반영 (3-2와 달리 충돌 없음) |
| node3 `systemctl stop mariadb` → node1에 `while-node3-down` INSERT | 남은 두 대로 쓰기 성공 |
| node3 `systemctl start mariadb` | 크기 3으로 복귀, 6줄 모두 보유. 로그 `Receiving IST: 3 writesets, seqnos 6-8`, `State transfer from 2.0 (node2) complete` → 빠진 3건만 받음(IST) |

id는 1, 2, 3, 5, 6, 7로 4를 건너뛰었다. Galera가 노드별로 auto_increment 간격을 조정해 번호 충돌을 막기 때문이다.

### Replication과 Galera 비교
| 항목 | Replication (3-2) | Galera (3-3) |
| --- | --- | --- |
| 쓰기 | 원본 한 대만 | 모든 노드 |
| 복제 방식 | 비동기 (원본이 먼저 확정) | 합의 후 확정 (가상 동기) |
| 복제본에 쓰면 | 충돌로 복제 정지 | 정상 반영 |
| 노드 장애 | 원본이 죽으면 수동 전환 필요 | 과반이 남으면 계속 쓰기 |
| 최소 대수 | 2대 | 3대 (쿼럼 때문) |
| 주의 | 복제 지연 감시 | 재시작 순서, 쓰기 지연 |

주의 자세히: Replication은 복제 지연(`Seconds_Behind_Master`)을 감시합니다. Galera는 전체 재시작 때 bootstrap 순서를 지켜야 하고, 대량 쓰기 때 클러스터 전체가 느려질 수 있습니다.

## 트러블슈팅

### 장애 1 · Keepalived 검사 스크립트가 SELinux에 막혀 조용히 꺼짐
- **증상:** VIP는 정상인데 로그에 `Unable to access script /usr/bin/systemctl - disabling`, `Disabling track script chk_nginx`
- **확인:** `ausearch -m avc -ts recent \| grep -c keepalived` → 2
- **원인:** Keepalived(`keepalived_t`)가 SELinux 정책상 `systemctl`을 직접 실행할 수 없음
- **조치:** 검사를 `/usr/libexec/keepalived/check_nginx.sh`로 옮기고 `restorecon` → 라벨 `keepalived_unconfined_script_exec_t`
- **확인:** `VRRP_Script(chk_nginx) succeeded`, nginx 중지 시 VIP 전환
- **재발 방지:** Keepalived 설정 후 로그에서 `VRRP_Script … succeeded`를 꼭 확인. SELinux를 끄지 않고 허용된 경로를 쓴다

### 장애 2 · live 스냅샷 멈춤 → VM 설정 파일 손상
- **증상:** 켜진 node1을 `--live`로 스냅샷 → 90%에서 1시간 멈춤. VM은 꺼졌는데 상태는 `onlinesnapshotting`
- **조치 1:** node2 정상 종료 후 `VBoxHeadless.exe`, `VirtualBox.exe`, `VBoxSVC.exe` 강제 종료
- **결과:** node1이 `<inaccessible>`로 바뀜
- **원인:** `…{b81598e6…}.vdi cannot be directly attached … because it has 1 differencing child hard disks`. 미완성 스냅샷이 만든 빈 디스크 조각(`{9ec85e7a…}`, 2MB)이 설정 파일에 자식으로 남음
- **조치 2:** `node1.vbox` 백업 → VBoxSVC 종료 상태에서 그 등록 한 줄 삭제
- **확인:** node1 정상 등록, 부팅 후 nginx · keepalived · VIP 모두 그대로 (작업 손실 없음)
- **재발 방지:** 스냅샷은 VM을 끄고 찍는다. 설정 파일을 고치기 전에는 반드시 백업

### 장애 3 · 복제본에 직접 써서 복제 정지 (일부러 재현)
- **재현:** node2에서 root로 `INSERT … VALUES (3, 'node2-direct', 9999)` → node1에서 `INSERT … ('mocha', 3200)` (id 3)
- **증상:** `Slave_IO_Running: Yes`, `Slave_SQL_Running: No`, `Last_SQL_Errno: 1062`, `Duplicate entry '3' for key 'PRIMARY'`
- **원인:** 복제본에 직접 쓴 줄과 원본의 새 줄이 같은 키. `read_only`는 관리자 권한 계정을 막지 못함
- **조치:** 원본 기준: node2에서 `DELETE … WHERE id=3 AND item='node2-direct'` → `START SLAVE`
- **확인:** Yes / Yes, 오류 0, GTID 0-1-6 일치, 세 줄 데이터 일치
- **재발 방지:** 복제본에 애플리케이션 계정만 두고 관리자 권한을 주지 않는다. 모니터링은 IO와 SQL 두 줄을 모두 본다. 충돌 이벤트 건너뛰기(skip)는 데이터 불일치를 남기므로 마지막 수단

### 장애 4 · 8.10 노드가 Galera에 합류할 수 없는 상태
- **증상:** node3의 `semanage port -l`에 Galera 포트가 `mysqld_port_t`로 없음. 기본 MariaDB는 10.3
- **원인:** 8.10 SELinux 정책과 모듈 기본값이 9.8과 다름
- **조치:** `dnf module enable mariadb:10.5`, `semanage port -m/-a -t mysqld_port_t`
- **확인:** 세 노드 `wsrep_cluster_size` 3, Synced
- **재발 방지:** 버전이 섞인 서버에 클러스터를 구성할 때는 패키지 버전과 SELinux 포트 정책을 먼저 비교한다

### 전체 재시작 실습 (11/13, 과제 6 시작 전)
세 대를 모두 끈 뒤 node1 · node3만 켜자 둘 다 `activating`에서 멈춤(서로 클러스터를 기다림).
```
node1 grastate.dat: seqno -1, safe_to_bootstrap: 0
node3 grastate.dat: seqno -1, safe_to_bootstrap: 1   ← 마지막에 정상 종료한 노드
```
두 노드 `systemctl stop mariadb` → node3 `galera_new_cluster`(크기 1, Primary) → node1 `systemctl start mariadb`(크기 2, 6줄 그대로).

## 배운 점
- Galera는 "어디에 써도 된다"가 장점이지만, 처음 시작과 전체 재시작은 한 노드에서 bootstrap해야 한다. 순서가 곧 안정성이다.
- 같은 Rocky라도 8.x와 9.x는 기본 패키지 버전과 SELinux 정책이 다르다. 섞어 쓰면 맞추는 작업이 따로 필요하다.
- 이중화는 "넘어가는지"뿐 아니라 "감시가 실제로 돌고 있는지"를 로그로 확인해야 한다. 과제 2의 miimon=0과 같은 유형의 문제가 SELinux 때문에도 생긴다.
- 복제는 IO와 SQL 두 단계다. 가져오기가 Yes여도 실행이 멈춰 있으면 데이터는 갈라진다.
- 원본이 정답이라는 원칙을 정해 두면 복구 방향이 분명해진다.
- 가상화 환경의 스냅샷도 장애 지점이 될 수 있다. 큰 작업 전 백업과 "끄고 찍기"를 습관으로.

## 연결
- 이전 과제: [2 · 네트워크 이중화(Bonding)](../02-network-bonding/)
- 다음 과제: [4 · Windows 11 최적화](../04-windows11-optimization/)
