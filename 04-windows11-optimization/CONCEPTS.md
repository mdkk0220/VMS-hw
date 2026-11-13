# 4 · Windows 11 최적화 · 개념 정리

> 무엇을, 왜 바꾸는지 정리한 문서입니다. 요약은 [README.md](./README.md)에 있습니다.

## 왜 Windows를 최적화하나

망분리와 가상화 환경에서는 사용자 PC 대신 **서버 위의 가상 PC(VDI)**를 많이 씁니다. 서버 한 대에 가상 PC 수십 대가 올라가기 때문에, 가상 PC 한 대에서 쓸데없이 도는 서비스 하나가 **수십 배로 곱해져** 서버 CPU, 메모리, 디스크를 잡아먹습니다.

카페에 비유하면, 손님 한 명은 신경 쓰지 않을 배경 음악이나 조명도 매장 50곳에서 동시에 켜면 전기 요금이 크게 차이 나는 것과 같습니다.

그래서 VDI에서는 사용자들이 복사해 쓰는 **원본 이미지(골든 이미지)**를 만들 때 최적화를 한 번 적용하고, 그 이미지로 가상 PC를 찍어 냅니다.

- Microsoft는 VDI용 Windows 최적화 항목을 문서로 정리하고, 같은 내용을 자동으로 적용하는 스크립트(**VDOT**, Virtual Desktop Optimization Tool)를 GitHub에 공개해 두었습니다.
- VMware(Omnissa) Horizon에도 같은 목적의 **OS Optimization Tool(OSOT)**이 있습니다. 바꾼 설정을 되돌리는 롤백 파일을 남기는 게 특징입니다.

## 최적화 항목 (무엇을, 왜)

각 항목은 **무엇을** 바꾸는지, 왜 바꾸는지, 바꿀 때 주의할 점 순서로 적었습니다.

**화면**

- **시각 효과(애니메이션, 투명도, 그림자) 끄기:** 원격 화면 전송량과 CPU 사용을 줄입니다.
    - 주의: 사용자가 "화면이 투박하다"고 느낄 수 있습니다.

**전원**

- **전원 계획 "고성능", 최대 절전 끄기(`powercfg -h off`):** VDI는 절전할 필요가 없고, 최대 절전 파일(hiberfil.sys)이 메모리 크기만큼 디스크를 차지합니다.
    - 주의: 노트북 같은 실물 PC에는 그대로 적용하지 않습니다.

**시작**

- **시작 프로그램 정리:** 로그인 시간을 줄입니다.
    - 주의: 보안 프로그램과 업무 프로그램은 남깁니다.

**서비스**

- **SysMain(Superfetch) 끄기:** 자주 쓰는 프로그램을 미리 메모리에 올리는 기능인데, VDI에서는 디스크 I/O만 늘립니다.
- **Xbox, 지도, 소매점 데모 같은 소비자용 서비스 끄기:** 업무용 PC에 필요 없습니다.
- **진단 추적(DiagTrack, 원격 분석) 줄이기:** 백그라운드 전송과 CPU 사용이 줄어듭니다. 망분리 환경에서는 외부 전송 자체가 막혀 있어 실패만 반복합니다.

**앱 · 백그라운드**

- **기본 설치된 스토어 앱(게임, 날씨 등) 제거:** 첫 로그인 때 앱 설치 과정이 사라져 로그인이 빨라집니다.
    - 주의: 사용자가 쓰는 앱인지 먼저 확인합니다.
- **백그라운드 앱, 알림, 팁 · 추천 끄기:** 불필요한 실행과 화면 갱신이 줄어듭니다.

**디스크**

- **예약된 디스크 조각 모음 끄기:** 가상 디스크에서는 실제 위치가 의미 없고, 조각 모음은 스토리지에 쓰기만 늘립니다.
- **임시 파일 정리, 저장소 센스:** 이미지 크기를 줄입니다.

**업데이트 · 보안 (끄지 않는 항목)**

- **자동 업데이트는 끄지 않고 관리 방식만 바꾸기:** 가상 PC마다 각자 업데이트하면 수십 대가 동시에 내려받아 네트워크와 디스크가 마비됩니다. 골든 이미지를 업데이트해서 다시 배포합니다.
    - 주의: 업데이트를 아예 끄면 보안 취약점이 쌓입니다.
- **백신(Defender)은 끄지 않기:** 보안은 최적화 대상이 아닙니다. VDI용 설정(검사 시간 분산, 공유 시그니처)으로 부하만 줄입니다.

## 하면 안 되는 최적화

- **백신 끄기, 방화벽 끄기, 업데이트 완전히 끄기.** 성능은 오르지만 보안 사고 위험이 훨씬 큽니다. 망분리 회사의 고객은 보안 때문에 망분리를 쓰는 곳입니다.
- **인터넷에서 받은 "최적화 프로그램"을 검증 없이 실행.** 무엇을 바꾸는지 모르고, 되돌릴 수 없는 경우가 많습니다.
- **되돌릴 방법 없이 적용.** 적용 전에 스냅샷(가상 PC)이나 복원 지점(실물 PC)을 만들고, 바꾼 항목을 기록합니다. 과제 2·3에서 "변경 전 스냅샷"을 습관으로 들인 것과 같은 원칙입니다.

## 효과는 어떻게 확인하나

"빨라진 느낌"이 아니라 숫자로 비교합니다.

| 측정 항목 | 확인 방법 |
| --- | --- |
| 실행 중인 프로세스 수 | 작업 관리자, 또는 `(Get-Process).Count` |
| 실행 중인 서비스 수 | `(Get-Service \| Where-Object Status -eq Running).Count` |
| 부팅 후 유휴 메모리 사용량 | 작업 관리자 → 성능 → 메모리 |
| 부팅 · 로그인 시간 | 이벤트 뷰어 → Diagnostics-Performance 로그(이벤트 ID 100) |
| 디스크 사용량 | `Get-PSDrive C` |

적용 전에 한 번, 적용하고 재부팅한 뒤 한 번 같은 방법으로 재서 표로 비교합니다.

## 사수가 물어볼 만한 질문

<details>
<summary>Q1. VDI에서 Windows 최적화가 왜 중요한가요?</summary>

서버 한 대에 가상 PC가 여러 대 올라가서, 가상 PC 한 대의 불필요한 서비스가 대수만큼 곱해져 서버 자원을 쓰기 때문입니다. 그래서 골든 이미지에 한 번 최적화를 적용해 모든 가상 PC에 반영합니다.
</details>

<details>
<summary>Q2. Windows Update를 꺼 버리면 안 되나요?</summary>

끄면 안 됩니다. 보안 취약점이 쌓입니다. 대신 가상 PC마다 각자 업데이트하지 않게 하고, 골든 이미지를 업데이트해서 다시 배포하는 방식으로 관리합니다.
</details>

<details>
<summary>Q3. 최적화를 적용하기 전에 무엇을 하나요?</summary>

되돌릴 수 있게 스냅샷이나 복원 지점을 만들고, 기준 수치(프로세스 수, 메모리, 로그인 시간)를 먼저 잽니다. 적용 후 같은 방법으로 다시 재서 효과를 숫자로 확인합니다.
</details>

<details>
<summary>Q4. 최적화하면 안 되는 항목은?</summary>

백신, 방화벽처럼 보안과 관련된 항목입니다. 성능보다 보안이 우선이고, 부하가 문제라면 끄는 대신 VDI용 설정으로 검사 시점을 분산합니다.
</details>

<details>
<summary>Q5. "가상 PC가 아침 9시마다 느려요"라는 문의가 오면?</summary>

같은 시각에 수십 대가 동시에 하는 일을 의심합니다. 로그인 폭주, 예약된 백신 검사, Windows Update, 조각 모음입니다. 가상 PC 한 대가 아니라 서버(호스트)의 CPU · 디스크 I/O를 함께 보고, 끄는 대신 시각을 분산하거나 골든 이미지에서 예약 작업을 정리합니다.
</details>

<details>
<summary>Q6. SysMain(Superfetch)은 왜 끄나요?</summary>

자주 쓰는 프로그램을 미리 메모리에 올리는 기능인데, 가상 디스크에서는 효과 없이 디스크 I/O만 늘리기 때문입니다.
</details>

## 참고 자료
- [Microsoft · Optimizing Windows for a VDI role](https://learn.microsoft.com/en-us/windows-server/remote/remote-desktop-services/rds-vdi-recommendations-2004)
- [Microsoft · Optimize Windows configuration for VDI](https://learn.microsoft.com/windows-server/remote/remote-desktop-services/remote-desktop-services-vdi-optimize-configuration)
- [Virtual Desktop Optimization Tool (VDOT), GitHub](https://github.com/The-Virtual-Desktop-Team/Virtual-Desktop-Optimization-Tool)
- [Windows OS Optimization Tool for Horizon Guide](https://techzone.omnissa.com/resource/windows-os-optimization-tool-horizon-guide)
