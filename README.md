# Calabiyau 중국 서버 한국어 최적화 패치

중국 서버 클라이언트의 문화권을 `zh-Hans`로 유지하면서 글로벌판 공식 한국어와
검증된 추가 한국어 번역을 표시하는 비공식 사용자 패치입니다.

## 대상

- Calabiyau WeGame 중국판
- 지원 게임 버전: `775419`, `777031`
- Windows PowerShell 5.1 이상

설치 스크립트가 게임의 `Version.txt`를 읽어 중국판 빌드 번호를 자동 감지하고,
`versions\<빌드 번호>`에 있는 정확히 일치하는 LOCRES만 선택합니다. 저장소에 없는
새 버전이면 오래된 패치를 적용하지 않고 안전하게 중단합니다.

## 최신 버전 777031 구성

- 글로벌 `1.10.1.3` 공식 한국어: 51,518개
- 공식 한국어가 없을 때 보존한 기존 번역: 10,066개
- 전체 한국어 엔트리: 61,584개
- 중국어 기본 표시 엔트리: 3,640개
- LOCRES 형식: v2, namespace 637개
- 파일 크기: 5,654,696바이트
- SHA-256: `36BCCADBB543512FB4CC6028844B7F3DF1D3456732F76D71FE066E2A1CE02961`
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
자동으로 찾고, 감지한 버전에 맞는 패키지의 파일 크기와 SHA-256을 모두 확인합니다.

설치 전 버전 감지만 확인하려면 다음 명령을 사용할 수 있습니다.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\detect_patch_version.ps1
```

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
- 버전 자동 감지, manifest 해시·크기 확인 및 경로 이탈 방지 검증
- 현재 버전 원본 PAK 106개 / SIG 106개 유지
- unsigned `Game_Patch_WindowsNoEditor_999_P.pak` 미사용

## 주의

- 게임 업데이트 후 저장소에 같은 빌드 번호의 패키지가 없다면 설치가 중단되는 것이 정상입니다.
- 신규 중국판 콘텐츠나 글로벌판과 충돌하는 텍스트는 중국어로 표시될 수 있습니다.
- 회사 저작권명, `日本語` 언어명, 맵 제작자명과 사용자명은 고유 표기를 유지합니다.
- 게임 내 탭 로딩 개선 정도는 저장장치, UI 자산 및 웹뷰 상태에 따라 다를 수 있습니다.
- 배포 전 [NOTICE.md](NOTICE.md)의 권리 관련 안내를 확인하세요.
