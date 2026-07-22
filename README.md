# Calabiyau 중국 서버 한국어 최적화 패치

중국 서버 클라이언트의 문화권을 `zh-Hans`로 유지하면서 글로벌판 공식 한국어와
검증된 추가 한국어 번역을 표시하는 비공식 사용자 패치입니다.

## 대상

- Calabiyau WeGame 중국판
- 게임 버전: `775419`
- Windows PowerShell 5.1 이상

다른 버전에서는 설치 스크립트가 자동으로 중단됩니다.

## 구성

- 공식 한국어 엔트리: 50,027개
- 추가 한국어 엔트리: 11,602개
- 전체 한국어 엔트리: 61,629개
- 미번역 유지: 4개 행 및 LOCRES 중복 식별자 충돌 1개 행
- LOCRES 형식: v2, namespace 638개
- 파일 크기: 5,648,387바이트
- SHA-256: `1DC783691F9CC8EF101E9695650E8BA17580B7D2281CA7B069198E85EC79A728`
- 폰트 raw-data cache: 32MB
- 문화권: `zh-Hans` 유지
- `Language=ko`: 사용하지 않음

PAK, SIG, 실행 파일, ACE 또는 서명 검사를 수정하거나 우회하지 않습니다.

## 설치

1. 게임을 완전히 종료합니다.
2. 이 저장소 폴더 전체를 Calabiyau 게임 설치 폴더 안에 둡니다.
3. 저장소 폴더에서 PowerShell을 열고 실행합니다.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\install_patch.ps1
```

스크립트는 상위 폴더를 검색해 `Version.txt`와 `PM\Content\Paks`가 있는 게임 루트를
자동으로 찾습니다.

설치되는 항목:

- `<게임 폴더>\PM\Content\Localization\Game\zh-Hans\Game.locres`
- `%LOCALAPPDATA%\Calabiyau\Saved\Config\WindowsNoEditor\Engine.ini`의 관리형
  32MB 폰트 캐시 블록

기존 대상 파일과 설정은 저장소의 `optimization_backups`에 백업됩니다.

## 제거

게임을 종료하고 실행합니다.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\remove_patch.ps1
```

알려진 패치 해시와 일치하는 loose LOCRES 및 이 패치가 추가한 설정 블록만 제거합니다.
다른 사용자 설정이나 원본 패키지 파일은 제거하지 않습니다.

## 확인된 사항

- LOCRES 직렬화 왕복 및 키·source hash·번역 일치 검증
- 설치 → 제거 → 원본 설정 해시 복구 → 재설치 왕복 검증
- PowerShell 스크립트 구문 및 설정 추가·제거 왕복 검증
- 원본 PAK 107개 / SIG 107개 유지
- unsigned `Game_Patch_WindowsNoEditor_999_P.pak` 미사용

## 주의

- 게임 업데이트 후에는 기존 패치를 제거하고 새 버전 호환 여부를 확인하세요.
- 신규 중국판 콘텐츠나 글로벌판과 충돌하는 텍스트는 중국어로 표시될 수 있습니다.
- 게임 내 탭 로딩 개선 정도는 저장장치, UI 자산 및 웹뷰 상태에 따라 다를 수 있습니다.
- 배포 전 [NOTICE.md](NOTICE.md)의 권리 관련 안내를 확인하세요.
