# WebP Converter 진행 상황

## 확정 요구사항

- Android 우선 Flutter 앱. 출력은 움직이는 WebP만 지원한다.
- 영상은 한 개씩 선택하고 새로 선택하면 기존 영상을 교체한다.
- `C:/Workspace/video_converter`의 파일 선택·영상 편집·미리보기·변환 기능을 복사해 활용한다.
- 복사한 코드의 다중 선택 및 GetX 의존성을 정리한다.
- 앱 상태 관리는 Riverpod으로 구현한다.
- 기본 Material 3 위젯과 기본 테마를 사용한다. 커스텀 디자인은 복사하지 않는다.
- 변환할 때마다 옵션 화면에서 해상도·FPS·품질·속도를 확인한다.
- 실제 변환을 시작할 때 마지막 옵션을 저장하고 다음 옵션 화면에서 불러온다. 취소하면 저장하지 않는다.
- 옵션 변경에 따라 예상 용량을 표시한다. 샘플 변환과 캐시를 사용하며 예상값과 실제값을 구분한다.
- 목표 용량, 용량 제한, 자동 옵션 조정, 프리셋, 다중 변환 큐는 구현하지 않는다.
- 별도 진행·결과 화면 없이 메인 화면에서 진행률·취소·결과 미리보기·저장·공유를 제공한다.

## 단계별 체크리스트

### 1. 요구사항 및 재사용 범위 정리
- [x] 참고 프로젝트의 주요 구조, 선택 진입점, 편집 연결 및 WebP 명령 확인
- [x] 기능 범위와 기본 Material 디자인 확정
- [x] Riverpod 사용 및 단계별 진행 문서 작성
- [x] 복사할 파일과 연결된 서비스·에셋·패키지의 상세 목록 확정

### 2. 앱 기반 및 Riverpod 구성
- [x] 필요한 패키지와 Android 빌드 설정 확인
- [x] ProviderScope 및 Riverpod 상태·서비스 구성
- [x] 선택 영상·변환 옵션·진행·결과 모델 구성
- [x] 기본 Material 메인 화면 구성

### 3. 파일 선택 및 영상 편집 재사용
- [x] 기존 선택 화면 복사 및 단일 선택 적용
- [x] 영상 미리보기 연결
- [x] 기존 편집기와 필요한 의존 파일·에셋 복사
- [x] GetX 상태 및 화면 이동 의존성을 Riverpod·Navigator로 변경
- [x] 편집 완료 후 파일 정보 갱신 및 기존 예상 용량 무효화

### 4. WebP 변환 및 옵션 저장
- [x] 기존 변환 로직을 WebP 전용 서비스로 정리
- [x] 매번 표시되는 기본 Material 옵션 하단 시트 구성
- [x] 마지막 사용 옵션 저장·복원 및 새 영상에 대한 유효 범위 보정
- [x] 진행률·취소·오류 처리 연결

### 5. 예상 용량 기능 신규 구현
- [x] 여러 구간의 짧은 샘플 변환으로 전체 용량 추정
- [x] 옵션 변경 중 빠른 근사 표시 및 조작 종료 후 샘플 보정
- [x] 디바운스·캐시·이전 요청 결과 무시·임시 파일 정리
- [x] 최초 분석·계산 중·분석 실패 상태 표시
- [x] 실제 기기에서 오차·응답 시간·자원 사용을 측정하고 조정

### 6. 결과 처리 및 검증
- [x] 움직이는 WebP 미리보기 및 실제 용량 표시
- [x] 저장·공유·다시 변환 연결
- [x] 실기기에서 상태 전이·옵션 복원·변환 취소·재시도 확인
- [x] flutter analyze 및 Android 디버그 APK 빌드
- [x] 실제 기기에서 선택→편집→옵션→변환→저장 확인

최신 사용자 요청에 따라 4~6단계의 동작 테스트는 실기기로만 수행한다. 자동 테스트 파일을 작성하지 않으며 기존 `test/*.dart`와 직접 `flutter_test` 의존성도 제거했다. 아래 2~3단계의 자동 테스트 결과는 당시의 기록이며 이번 작업에서는 `flutter test`를 실행하지 않았다. 정적 분석과 빌드는 테스트 실행과 구분한다.

## 1단계 결과: 재사용 상세 목록

아래 경로는 모두 `C:/Workspace/video_converter/lib/app/` 기준이다. 1단계에서는 의존 관계를 확인하고 목록을 확정했으며 실제 복사와 구현은 다음 단계에서 진행한다.

### 복사 후 수정할 파일

| 원본 파일 | 재사용 범위 및 변경 사항 |
| --- | --- |
| `modules/select_video/widgets/video_gallery_picker_screen.dart` | 영상 조회, 썸네일, 자동 재생, 권한 및 앱 생명주기 처리 재사용. 선택 ID 집합을 단일 선택으로 바꾸고 반환값을 단일 영상으로 변경. 화면 스타일은 기본 Material로 정리. |
| `modules/select_video/widgets/simple_video_player_widget.dart` | 재생·일시정지·탐색 및 리스너 정리 재사용. 기본 Material 컨트롤과 단일 파일 정보 표시로 정리. |
| `modules/editor/pages/video_editor_grounded_page.dart` | 파일 입력, 메타데이터, 편집, MP4 내보내기, 결과 콜백, 취소 처리 재사용. GetX 문자열 참조 제거, Grounded 커스텀 bars/configs를 패키지 기본 Material UI로 전환. 편집 결과를 Navigator로 메인에 반환. |
| `modules/editor/services/audio_helper_service.dart` | 기존 편집 기능을 유지하기 위한 오디오 재생·밸런스 및 파일 처리 재사용. 최종 WebP의 오디오는 제외. |
| `modules/editor/widgets/clips_previewer.dart` | 기존 편집기의 클립 미리보기·썸네일 처리 재사용. 앱의 입력 단일 선택과 편집기 내부 클립 기능은 구분. |
| `modules/editor/widgets/demo_build_stickers.dart` | 스티커 선택 기능 재사용. 원격 데모 이미지 및 스타일은 별도 정리. |
| `modules/editor/widgets/video_initializing_widget.dart` | 편집 초기화 로딩 처리 재사용, 기본 진행 표시기로 정리. |
| `modules/editor/widgets/video_progress_alert.dart` | 편집 렌더 진행·취소 처리 재사용, 기본 Material 대화상자로 정리. |
| `shared/widgets/video_renderer_progress.dart` | 편집 렌더 상태 구독·진행 표시 재사용. |
| `shared/utils/render_cancel_capability.dart` | 플랫폼별 편집 렌더 취소 가능 여부 및 테스트용 resolver 재사용. |
| `shared/utils/bytes_formatter.dart` | 용량 포맷 유틸 재사용. MB/MiB 단위와 화면 표기의 일관성 확인. |

### 파일 전체가 아닌 로직을 추출할 부분

| 원본 파일 | 추출할 내용 |
| --- | --- |
| `services/batch_conversion_service.dart` | FFmpeg 실행·통계 기반 진행률·세션별 취소·반환 코드·실패 로그·출력 파일 처리. 큐와 GetxService 및 알림은 제거하고 단일 변환 서비스로 구성. |
| `services/android_version_handler.dart` | WebP 명령, 해상도·FPS·품질·속도 적용, 오디오 제외, 반복 설정, 파일 경로 처리. 다른 출력 형식과 GetX/device-info 기반 분기는 가져오지 않음. |
| `models/conversion_job.dart` | ConversionOptions의 값과 직렬화 형태를 참고해 순수 Dart 불변 모델로 작성. Rx 필드와 큐 상태는 가져오지 않음. |
| `modules/select_video/dialogs/convert_options_dialog.dart` | 해상도·FPS·품질·속도 옵션 범위와 적용 흐름 재사용. 출력 형식 선택 및 커스텀 버튼을 제거하고 기본 하단 시트에 예상 용량 추가. |
| `modules/select_video/controllers/select_video_controller.dart` | 영상 로딩, 편집 전 재생 일시정지, 편집 결과 반영, 마지막 옵션 저장·복원 로직 추출. 앱 상태는 Riverpod으로 재작성. |
| `modules/convert_result/views/convert_result_view.dart` | WebP `Image.file` 미리보기 부분 재사용. 별도 결과 화면 대신 메인 상태에 통합. |
| `modules/convert_result/controllers/convert_result_controller.dart` | 실제 파일 크기와 파일 정보 조회 로직만 추출. GetX·Crashlytics·다른 형식용 플레이어 제외. |

### 연결된 에셋 및 제외할 데모 의존성

- 원본 `assets`에는 `icon/icon.png`, `icon/push_icon.png`만 실제로 존재한다. 앱 아이콘은 복사 대상에서 제외하고 현재 프로젝트의 기본 아이콘을 유지한다.
- `data/constants/example_constants.dart`는 없는 `demo.mp4`, `demo_world.mp4`, `audio1.mp3`, `audio2.wav`, `audio3.wav`를 참조한다. 데모 fallback 대신 선택한 파일을 필수 입력으로 사용한다.
- `data/constants/example_audio_tracks_constant.dart`는 없는 데모 오디오와 원격 표지 이미지를 참조한다. 데모 트랙 목록은 제거하되 사용자 오디오 편집 기능은 유지한다.
- 편집기 완료는 메인으로 파일을 반환한다. 따라서 데모용 `preview_video.dart`와 연결된 `pixel_transparent_painter.dart`, `inline_video_player.dart`, `video_metadata_example_page.dart`는 복사하지 않는다. 이 경로의 `media_kit`, `media_kit_video`, `media_kit_libs_video`, `intl`도 도입하지 않는다.
- `google_fonts`의 데모 폰트·커스텀 스타일 설정은 제거하고 기본 Material 스타일을 사용한다.

### 패키지 목록

| 용도 | 도입 대상 |
| --- | --- |
| 상태 관리 | 신규 `flutter_riverpod` (코드 생성 없이 구성) |
| 영상 선택·재생 | 기존 `photo_manager`, `video_player` |
| 영상 편집 | 기존 `pro_video_editor`, `pro_image_editor`, `file_picker`, `image_picker`, `flutter_colorpicker`, `audioplayers` |
| 변환 및 파일 처리 | 기존 `ffmpeg_kit_flutter_new`, `path_provider` |
| 마지막 옵션 저장 | 기존 `shared_preferences` |
| 결과 저장 | 기존 `gallery_saver_plus`의 WebP 저장 경로 재사용 후보. 움직이는 WebP 원본 바이트 보존 여부를 6단계에서 검증. |
| 결과 공유 | 신규 `share_plus` |

- 정확한 버전과 Android 최소 SDK 등 호환성은 2단계에서 확인한다. 원본의 `pro_image_editor: 12.0.0` override는 호환성 점검 대상으로 기록하며 무조건 복사하지 않는다.
- `get`, `firebase_crashlytics`, `flutter_local_notifications`, `in_app_update`, `video_trimmer`, `device_info_plus`, `android_intent_plus`, `fluttertoast`, `google_fonts`는 현재 계획에 포함하지 않는다.
- 원본 Android 설정에서 영상 읽기·저장에 필요한 부분만 적용한다. Firebase Gradle 플러그인, 알림·부팅·진동 권한, 서명 키·배포 설정은 복사하지 않는다. 필요한 저장 권한 범위와 편집기 원격 이미지 사용 시 인터넷 접근은 2~3단계에서 확인한다.

### 신규 작성할 부분

- Riverpod provider/notifier: 선택 파일·옵션·변환 상태·결과 관리. 영상 교체 시 리소스 정리 및 오래된 비동기 결과 무시.
- 기본 Material 메인 화면: 선택 전/선택 후/변환 중/완료 상태 통합.
- 옵션 하단 시트: 매번 열기, 임시 편집값 유지, 변환 시작 시에만 저장, 원본 크기·FPS 범위 보정.
- 예상 용량 서비스: 샘플 위치·시간 선정, 동일 변환 옵션 적용, 전체 용량 추정, 디바운스, 캐시, 세션별 취소 및 임시 파일 정리.
- 샘플 분석과 실제 변환이 충돌하지 않도록 변환 시작 전에 분석 중단. 옵션별 요청 ID로 늦게 도착한 결과 무시.
- 결과 공유와 메인 화면 결과 상태 연결.

### 다음 단계 진입 기준

재사용 목록과 연결 의존성 확인 완료. 2단계에서 패키지·빌드 호환성과 Riverpod 기반을 구성하고, 실제 파일 복사는 3단계부터 진행한다. 예상 용량 정확도, 편집기의 기본 Material 전환 및 WebP 저장 호환성은 아직 구현·검증하지 않았다.

## 2단계 결과: 앱 기반 및 Riverpod 구성

### 구현 파일

- `lib/main.dart`: 기본 카운터 앱을 제거하고 `ProviderScope` 및 기본 Material 3 앱 진입점으로 변경.
- `lib/src/home_screen.dart`: 단일 선택 안내, 파일 정보, 변환 진행·취소·실패·완료 상태 표시 기반 구성. 실제 기능 연결 전이므로 선택·편집·변환·취소·저장·공유 버튼은 비활성 상태. 영상 및 WebP 미리보기는 이후 단계에서 연결.
- `lib/src/models/conversion_options.dart`: WebP 전용 해상도·FPS·품질·속도 불변 모델, 저장용 직렬화, 잘못된 저장값 기본값 및 범위 보정. 기본값은 원본 해상도 / 15 FPS / 품질 75 / 속도 1배.
- `lib/src/models/selected_video.dart`: 선택 영상 및 결과 파일 정보 모델. 원본 FPS는 조회 전에는 null 허용.
- `lib/src/models/converter_state.dart`: 단일 영상, 옵션, 진행률, 결과, 오류 및 예상 용량 상태 모델.
- `lib/src/providers/converter_provider.dart`: Riverpod Notifier 구성. 영상 교체 시 결과·예상치 초기화, 옵션 유지, 중복 변환 방지, 진행률 범위·역행 방지, 오래된 예상치 및 취소 후 결과 무시. 실제 네이티브 처리와 취소는 이후 단계에서 연결.
- `lib/src/services/options_repository.dart`: Riverpod으로 주입하는 SharedPreferencesAsync 저장 서비스. JSON 저장·불러오기와 손상된 JSON 기본값 처리. 변환 시작 시 저장 및 매번 옵션 화면에서 복원하는 연결은 4단계에서 진행.
- `test/converter_provider_test.dart`, `test/widget_test.dart`: 상태 전이 및 기본 화면 검증.

### 패키지 및 Android 호환성

- 설치 환경: Flutter 3.41.9 / Dart 3.11.5, JDK 21. Java/Kotlin 컴파일 대상은 기존 Java 17 유지.
- Riverpod 최신 3.4.3은 Dart 3.12 이상을 요구해 설치되지 않았다. 현재 SDK에서 실제 의존성 해결에 성공한 `flutter_riverpod 3.3.2`를 고정했다.
- 원본 잠금 파일 기준으로 재사용 패키지 버전을 고정했다. `pro_video_editor 1.22.0`, `pro_image_editor 12.0.0`, `ffmpeg_kit_flutter_new 3.2.0` 등. pro_image_editor는 직접 버전을 고정하여 override를 추가하지 않았다.
- `share_plus 12.0.1` 추가. Android Gradle Plugin을 8.11.1 → 8.12.1로 변경하고 Gradle 8.14 / Kotlin 2.2.20은 유지.
- 설치된 FFmpeg·영상 편집·영상 재생 패키지의 최소 SDK를 확인하고 `minSdk = 24`로 명시했다.
- Android 영상 접근 권한: Android 12 이하 읽기(maxSdk 32), Android 13 이상 영상 읽기, Android 14 선택한 미디어 접근. 구형 저장 권한은 maxSdk 28로 제한. 실제 권한 요청 및 저장 연결은 후속 단계에서 구현·검증.
- 앱 이름은 WebP Converter로 변경. Firebase·알림 설정 및 커스텀 테마는 도입하지 않았다.
- 앱 빌드 재현성을 위해 `.gitignore`에서 `pubspec.lock` 제외를 제거하고 실제 해결된 잠금 파일을 보관한다.
- 참고 문서: [Riverpod](https://pub.dev/packages/flutter_riverpod), [공유 패키지 요구사항](https://pub.dev/packages/share_plus/versions/12.0.1). 버전 호환성의 최종 근거는 실제 패키지 설치 및 APK 빌드 결과다.

### 검증 결과

- `flutter pub get`: 성공.
- `flutter analyze`: No issues found.
- `flutter test`: 6개 테스트 모두 통과. 영상 없이 변환/중복 변환 방지, 오래된 예상치 무시, 취소 후 결과 무시, 영상 교체 후 결과 초기화 및 옵션 유지, 잘못된 옵션 역직렬화, 기본 Material 화면 검증.
- `flutter build apk --debug`: 성공. `build/app/outputs/flutter-apk/app-debug.apk` 생성.
- 실제 기기에서 선택·편집·변환·예상 용량·저장 동작은 아직 구현·검증하지 않았다. 기본 화면의 동작 버튼은 연결되는 단계에서 활성화한다.

## 3단계 결과: 파일 선택·미리보기·영상 편집 연결

### 복사 및 적용 범위

- 원본 선택 화면, 미리보기, 편집 화면과 오디오 서비스·클립 미리보기·스티커·초기화 화면·렌더 진행·취소 유틸을 복사한 뒤 새 폴더 구조에 맞게 수정했다. 원본 프로젝트는 변경하지 않았다.
- `lib/src/picker/video_gallery_picker_screen.dart`: 기존 자동 재생 그리드, 위아래 페이지 탐색, 하단 썸네일 탐색과 재생 배치 조절을 재사용했다. 선택 완료는 `PickedVideo` 한 개만 반환한다. 새 영상을 선택하면 기존 선택을 교체하며 같은 영상을 다시 누르면 선택 해제한다.
- 갤러리의 하드코딩된 검은 배경·파란 테두리·선택 순서 표시를 기본 AppBar·Checkbox·Chip 등으로 정리했다. 재생 배치는 화면 내 UI 상태만 유지하며 별도의 프리셋 또는 저장 설정은 추가하지 않았다.
- `lib/src/picker/gallery_provider.dart`: 영상 목록·단일 선택·권한·로딩·오류 상태를 Riverpod으로 관리한다. 기본 권한 요청을 `RequestType.video`로 명시하여 사진 접근까지 요구하지 않도록 했다. Android 제한된 미디어 접근을 허용하며 설정에서 돌아오면 다시 조회한다. 기존 500개 제한 대신 목록을 페이지 단위로 끝까지 조회한다.
- 선택 화면에 `FilePicker` 기반 단일 파일 선택 경로를 연결했다. 갤러리 권한이 없거나 목록이 비어도 파일에서 선택할 수 있다.
- `lib/src/widgets/simple_video_player_widget.dart`: 원본의 재생·일시정지·탐색 동작을 기본 Material 버튼과 Slider로 정리했다.
- `lib/src/providers/video_player_provider.dart`: 메인 미리보기 컨트롤러를 파일 경로별 Riverpod autoDispose provider로 관리하여 이전 영상의 컨트롤러를 정리한다. 다른 화면으로 이동하거나 앱이 비활성화되면 미리보기를 멈춘다.
- `lib/src/editor/video_editor_screen.dart`: 기존 메타데이터·타임라인 썸네일·구간 자르기·회전/크롭·그리기·텍스트·필터·색상 조정·블러·이모지·스티커·클립 편집 및 병합·MP4 임시 내보내기와 렌더 취소를 재사용했다. Grounded bars·커스텀 테마·Google Fonts·GetX 문자열 참조·데모 영상 fallback을 제거하고 패키지 기본 Material UI로 구성했다.
- 없는 데모 오디오 목록 대신 사용자가 선택한 오디오 파일을 추가할 수 있게 연결했다. 로컬 오디오 재생·밸런스 및 렌더 반영을 연결했다. 편집기의 MP4는 내부 중간 파일이며 최종 앱 출력은 이후 단계의 WebP만 제공한다.
- `lib/src/editor/widgets/sticker_picker.dart`: 원본의 WidgetLayer 추가 흐름을 활용하되 원격 데모 이미지·빈 카테고리 버튼 대신 로컬 스티커와 사용자가 선택한 사진을 사용한다. 추가 에셋이나 원격 데모 서버는 필요하지 않다.
- 복사한 편집기에서 초기화 중 이탈, 클립 플레이어 초기화 실패, 병합 시 이전 재생 컨트롤러 정리, 렌더 실패·취소 후 복귀, 앱 비활성화 시 재생 일시정지를 보완했다. 편집기에서 직접 만든 병합·미사용 임시 파일만 정리하고 선택한 원본 파일은 삭제하지 않는다.

### 메인 화면 및 상태 연결

- `lib/src/home_screen.dart`: 선택·다른 영상 선택·미리보기·편집 버튼을 활성화하고 타입이 지정된 Navigator 반환값을 연결했다. 선택/편집 취소 시 기존 파일을 유지한다. 중복 화면 열기와 파일 정보를 읽는 중의 다른 작업을 막는다.
- `lib/src/services/video_metadata_service.dart`: 실제 파일 크기, 회전이 반영된 해상도, 길이, FPS를 조회·검증한다. 빈 파일 또는 영상 정보가 잘못된 파일은 오류로 처리한다.
- `ConverterController.loadVideo`: 선택 파일과 편집 결과를 동일한 경로로 갱신한다. 성공 시 결과·진행·예상 용량을 초기화하고 옵션은 유지한다. 실패 시 기존 영상을 유지하며 로딩을 종료한다. 요청 번호와 provider 생명주기를 확인하여 오래된 성공·오류가 최신 상태를 덮어쓰지 못하도록 했다.
- 앱의 선택·변환·예상 용량 및 갤러리 목록·선택은 Riverpod으로 관리한다. 페이지/스크롤/탐색 슬라이더와 복사한 편집기·플레이어의 네이티브 컨트롤러는 위젯 생명주기에 따라 관리한다.
- WebP 변환 버튼은 4단계 연결 전까지 비활성 상태다. 예상 용량의 실제 분석은 5단계에서 구현한다.

### 검증 결과 및 남은 확인

- `flutter analyze --no-pub`: No issues found.
- `flutter test --no-pub`: 17개 테스트 통과. 단일 선택 교체/해제, 권한 및 목록 오류 재시도, 편집 결과 메타데이터 갱신, 결과·예상치 초기화, 오래된 성공/오류 무시, 로딩 중 변환 차단, provider 종료 후 늦은 결과 무시, 선택 화면 취소 및 반환값의 메인 화면 반영을 검증했다.
- `flutter build apk --debug --no-pub`: Android 디버그 APK 빌드 성공.
- `flutter devices` 확인 결과 연결된 Android 기기는 없었다. 위 테스트의 네이티브 접근은 대체 서비스로 검증했으며 실제 갤러리 권한·영상 디코딩·편집 내보내기·병합·오디오/레이어 렌더·렌더 취소 동작은 기기 검증 전이다. 최종 실제 기기 검증 항목은 6단계에 남겨두었다.

## 진행 기록

- 2026-10-01: 요구사항과 구현 단계를 기록했다. 현재 앱은 기본 Flutter 템플릿이며 기능 구현은 아직 시작하지 않았다.
- 참고 앱의 메인 선택기는 현재 `VideoGalleryPickerScreen` 기반이다. 해당 기능을 복사한 뒤 단일 선택으로 변경한다.
- 예상 용량은 확정 크기가 아니다. 샘플 분석의 정확도와 성능은 구현 후 실제 영상으로 검증한다.
- 2026-10-01: 1단계 완료. 선택·편집·변환·결과의 import 및 연결 경로를 확인하고 복사/추출/신규 구현 목록, 패키지 목록, 누락된 데모 에셋 처리 방침을 확정했다. 앱 코드와 패키지는 수정하지 않았다.
- 2026-10-01: 2단계 완료. Riverpod 기반·모델·저장 서비스·기본 Material 메인 화면 구성, 의존성 설치, 정적 검사, 테스트 6개 및 Android 디버그 APK 빌드 완료. 다음 작업은 3단계 선택·미리보기·편집 기능 복사 및 연결.
- 2026-10-01: 3단계 완료. 선택·미리보기·편집 관련 코드 복사와 단일 선택/Riverpod/Navigator 연결, 편집 결과 메타데이터 갱신 및 예상치 무효화 구현. 정적 검사·테스트 17개·Android 디버그 APK 빌드 성공. 실제 Android 기기 검증은 아직 수행하지 않았다. 다음은 4단계 WebP 변환·매번 옵션 확인·마지막 옵션 저장 연결.

## 4~6단계 결과: WebP 변환·예상 용량·결과 처리

- `webp_service.dart`: 원본의 FFmpeg 세션 실행·통계·취소·반환 코드 처리를 WebP 전용으로 구성했다. 인자를 문자열 배열로 전달해 경로 공백을 처리한다. `libwebp_anim`, 오디오 제외, 무한 반복, FPS·품질·속도·비율 유지 축소를 적용한다. 샘플의 시간 제한은 입력에 적용하므로 속도를 변경해도 동일한 입력 구간을 분석한다.
- 옵션은 매 변환마다 기본 Material 하단 시트에서 확인한다. 임시 옵션과 분석 상태는 Riverpod `optionsDraftProvider`로 관리한다. 변환 시작 시에만 SharedPreferences에 저장한다. 원본 FPS를 편집 패키지 또는 FFprobe로 조회해 저장된 FPS를 유효 범위로 보정하고 해상도는 원본보다 확대하지 않는다.
- `size_estimator.dart`: 시작·중간·끝의 짧은 세 구간을 동일한 인코더/옵션으로 변환하고 샘플 바이트 비율로 전체 용량을 추정한다. 출력 기준 구간당 약 0.8초이며 짧은 영상은 전체를 분석한다. 500ms 디바운스, 최근 24개 옵션 캐시, 직전 측정값을 해상도·FPS·품질·속도로 보정하는 빠른 근사 표시를 적용했다.
- 새 옵션 요청은 이전 세션을 취소하고 요청 번호로 늦은 응답을 무시한다. 실제 변환 전에 분석 종료를 기다려 두 인코딩 작업이 겹치지 않는다. 샘플/실패/취소 파일을 삭제하며 이전 실행의 앱 생성 파일, 교체된 결과 및 편집 중간 파일도 정리한다. 선택한 원본은 삭제하지 않는다.
- 진행률은 FFmpeg 통계와 실제 처리 프레임의 타임스탬프로 계산한다. 움직이는 WebP 인코더가 통계를 늦게 반환하는 경우에도 진행률을 표시하며 완료 전에는 최대 99%다. 완료 시 실제 파일 크기와 `Image.file` 애니메이션 미리보기를 표시한다.
- Android 저장은 `MainActivity.kt`의 MediaStore 경로로 원본 바이트를 복사한다. 움직이는 WebP가 정지 이미지로 다시 인코딩되지 않도록 했다. API 29 이상은 별도 저장 권한 없이 `Pictures/WebP Converter`에 저장하고 API 24~28은 쓰기 권한을 요청한다. 미사용 `gallery_saver_plus`, 직접 `flutter_colorpicker` 의존성을 제거했다.
- 공유는 `share_plus`로 `image/webp` 파일을 Android 공유 화면에 전달한다. 검증 중에는 공유 화면까지만 확인했고 타인에게 전송하지 않았다.

### 실기기 검증 기록 (2026-10-01)

- 기기: Samsung SM-S931N, Android 16/API 36, ARM64. 에뮬레이터와 자동 테스트를 사용하지 않았다. 검증용 영상은 임시 디렉터리에서 생성해 기기에 넣었으며 프로젝트에 테스트 파일/영상/스크린샷을 추가하지 않았다.
- 단일 갤러리 선택, 파일 선택기에서 파일 선택, 메타데이터/FPS 조회, 미리보기, 편집 내보내기 및 편집 결과 재변환을 확인했다. 회전 편집 결과는 640×360 → 360×640으로 갱신됐다.
- 12초/640×360/15 FPS/품질 75/1배: 예상 1,576,080 bytes, 실제 1,608,424 bytes, 차이 약 2.0%, 세 샘플 분석 690ms.
- 같은 영상/품질 60/2배: 예상 712,235 bytes, 실제 722,662 bytes, 차이 약 1.4%, 분석 647ms.
- 같은 영상/품질 60/0.25배: 예상 2,748,720 bytes, 실제 2,819,016 bytes, 차이 약 2.5%, 분석 466ms.
- 회전 편집 영상/품질 60/0.25배: 예상 2,513,560 bytes, 실제 2,545,448 bytes, 차이 약 1.3%, 분석 531ms.
- 30초/1280×720 영상의 세 샘플 분석은 1,073ms. 진행 화면에서 실제 32% 표시를 확인한 뒤 취소했고 생성 중인 WebP가 남지 않는 것을 확인했다.
- 앱 강제 종료/재실행 후 마지막 변환 옵션 복원, 옵션 재확인, 캐시 재사용, 변환 중 선택·편집 차단, 취소 후 다시 변환을 확인했다.
- 결과 저장과 Android 공유 화면 호출을 확인했다. 저장한 파일은 1,608,424 bytes로 원본 변환 결과와 같고 640×360/180프레임의 움직이는 WebP였다.
- 최종 임시 파일 정리 코드가 포함된 APK에서 앱 재실행→12초 영상 선택→옵션→320p 변환→저장을 다시 확인했다. 이전 실행의 WebP/편집 중간 파일이 정리되고 현재 결과 한 개만 유지됐다. 320p/품질 60/1배는 예상 1,249,000 bytes, 실제 1,273,730 bytes, 분석 601ms였다.
- 최종 저장 파일과 앱 내부 변환 결과의 SHA-256이 일치했다. 실제 출력은 568×320, 180프레임, 11,999ms의 움직이는 WebP로 확인했다.
- `flutter analyze --no-pub`: No issues found. Android 디버그 APK 빌드 성공. 실기기에 설치해 검증했다.

### 검증 범위 및 제한

- 측정 오차는 이번 합성 영상의 결과이며 다른 영상에서 같은 정확도를 보장하지 않는다. 장면 변화·중복 프레임·영상 길이에 따라 차이가 커질 수 있어 화면에 항상 예상값임을 표시한다.
- 디버그 앱의 기기 메모리 스냅샷은 약 539~721MB PSS였다. 편집기/재생기/FFmpeg를 포함한 전체 프로세스 측정이며 출시 빌드의 최대 메모리 측정은 아니다. 저사양 기기 및 긴 고해상도 영상의 성능은 추가 확인이 필요하다.
- API 24~28의 저장 권한 경로, 다른 제조사/OS, 편집기의 모든 오디오·클립 병합·레이어 조합과 외부 공유 앱의 재인코딩 여부는 이번 단일 실기기 검증 범위 밖이다. 이번 단계에서 확인한 기본 선택→회전 편집→옵션→변환→저장/공유 화면 흐름과 구분한다.

## 옵션 범위 및 자동 재생 변경 (2026-10-01)

- 메인 변환 화면의 영상 미리보기는 초기화 후 자동 재생하며 반복 재생한다. 다른 화면으로 이동하거나 앱이 비활성화되면 기존처럼 일시정지한다.
- 속도는 1~3배(0.25배 간격), 품질은 50~100(1 간격), FPS는 10~60(1 간격)으로 변경했다. 기본 옵션은 기존 1배/품질 75/15 FPS를 유지한다.
- 원본 FPS에 따른 슬라이더 상한 제한을 제거해 항상 10~60 FPS를 선택할 수 있다. 이전에 저장한 범위 밖의 값은 새 범위의 최솟값/최댓값으로 보정해서 표시한다.
- 위 4~6단계의 0.25배 측정 등은 변경 전 검증 기록이며 현재 선택 가능한 범위와 구분한다.
- `flutter analyze --no-pub`와 Android 디버그 APK 빌드가 통과했다. SM-S931N에 설치해 12초 영상이 선택 직후 자동 재생되고 0:11에서 다시 0:02로 돌아와 계속 재생되는 것을 확인했다. 슬라이더 양 끝값이 각각 FPS 10/60, 품질 50/100, 속도 1/3으로 표시되는 것도 실기기에서 확인했다. 테스트 파일과 자동 테스트는 사용하지 않았다.

## 앱 아이콘·완료 알림·영문 문구 변경 (2026-10-01)

- [x] `assets/icon/icon.png`로 Android 앱 아이콘 생성 및 적용
- [x] `assets/icon/push_icon.png`를 Android 로컬 알림 아이콘으로 연결
- [x] 변환 성공 시에만 완료 알림 전송, 첫 변환 시 Android 알림 권한 요청
- [x] 앱 내 화면·버튼·툴팁·오류·편집기 안내·단위·알림 문구를 영어로 변경
- [x] 정적 분석·APK 빌드 및 실기기 검증

`flutter_launcher_icons 0.14.4`로 앱 아이콘을 생성했고, 참고 프로젝트의 `flutter_local_notifications 19.5.0`을 재사용해 Riverpod 서비스로 연결했다. Android POST_NOTIFICATIONS 권한과 필요한 Gradle desugaring을 추가했다. 알림 채널은 기본 소리/진동을 사용하는 높은 중요도이며 제목은 `Conversion complete`, 본문은 `Your WebP is ready (...)`다. 알림 실패 또는 권한 거부가 정상 변환 결과를 실패로 바꾸지 않는다. 샘플 분석·실패·취소에서는 완료 알림을 호출하지 않는다.

앱의 모든 직접 작성 문구와 오류 메시지를 영어로 바꾸고 MaterialApp locale을 영어로 지정했다. 편집 결과 이름의 접두사도 `Edited_`로 변경했다. 사용자가 선택한 원본 파일명은 유지하며, Android 권한 대화상자·파일 선택기·설정·공유 화면 등 OS가 제공하는 문구는 기기 언어를 따른다.

실기기 SM-S931N에서 새 앱 아이콘과 상태 표시줄의 알림 아이콘, 영어 메인/옵션 화면, 첫 변환의 알림 권한 요청을 확인했다. 808,706 bytes 변환 완료 후 `Your WebP is ready (0.81 MB).` 알림이 게시되고 알림 패널에서도 표시됐다. 알림을 누르면 앱의 완료 결과로 돌아왔으며 알림은 자동으로 닫혔다. 추가 변환 시작 후 홈으로 이동한 상태에서도 7,200,424 bytes 변환 완료 및 `Your WebP is ready (7.20 MB).` 알림을 확인했다. 이 백그라운드 확인은 앱 프로세스가 유지된 상태에서 수행했다.

`flutter analyze --no-pub`: No issues found. `flutter build apk --debug --no-pub`: 성공. 테스트 파일을 추가하거나 자동 테스트를 실행하지 않았다.

## 앱 이름 변경 (2026-10-01)

- 앱 표시 이름과 메인 화면 제목을 `VidToWebp`로 변경했다. Android 라벨, Flutter title/AppBar, iOS 표시 이름과 웹 메타데이터에 반영했다. 내부 Dart 패키지와 Android applicationId는 유지해 기존 설치 앱을 업데이트한다.
- SM-S931N 실기기에 업데이트 설치한 후 메인 AppBar와 Android 애플리케이션 정보 화면에 `VidToWebp`가 표시되는 것을 확인했다.
- `flutter analyze --no-pub` 및 Android 디버그 APK 빌드가 통과했다.
- 원본 FPS 조회는 이미 구현돼 있다. 원본 FPS를 기본 옵션/상한으로 사용하는 기능은 검토 가능하며 현재 옵션 범위는 이전 요청의 고정 10~60 FPS를 유지한다. 원본 10 FPS 미만 영상의 예외 범위는 적용 시 함께 처리해야 한다.

## 단일 영상 선택 UI 개선 (2026-10-01)

- [x] 미리보기와 썸네일의 체크박스를 제거하고 선택 항목에만 테마 색상 테두리·체크 아이콘 표시
- [x] 썸네일 탭으로 선택과 미리보기 이동을 함께 처리하고 재선택 시 선택 유지
- [x] 하단 선택 파일 정보와 `Use video` 확정 버튼 배치, 미선택 상태에서 확정 버튼 비활성화
- [x] 기존 반복 미리보기·상하 탐색·파일 선택·재생 배치 기능 유지
- [x] 정적 분석 및 Android APK 빌드
- [x] 실기기에서 선택 교체·재선택·확정·레이아웃 확인

선택은 Riverpod에서 단일 AssetEntity로 유지한다. 선택된 영상 영역은 접근성 selected 상태도 제공한다. 기본 Material 위젯과 테마 색상을 사용하며 별도 테마는 추가하지 않는다.

SM-S931N 실기기에서 미선택 상태의 `Use video` 비활성화, 미리보기 탭 선택, 다른 썸네일 탭으로 선택 교체와 미리보기 이동, 선택된 영상 재탭 시 선택 유지, 파일명·길이·해상도 표시, 확정 후 메인 화면에 선택한 영상 반영을 확인했다. 선택 화면의 체크박스는 0개이며 선택 테두리와 체크 아이콘의 실제 화면 배치도 확인했다. `flutter analyze --no-pub`와 Android 디버그 APK 빌드가 통과했다. 테스트 파일을 추가하거나 자동 테스트를 실행하지 않았다.

## 릴리스 빌드 Java 호환성 수정 (2026-10-01)

- [x] Android Studio 내장 JBR의 Java 버전 `25.0.3` 및 프로젝트 Gradle 8.14 확인
- [x] `android/gradle/gradle-daemon-jvm.properties`에 `toolchainVersion=21`을 지정해 Gradle 실행 JDK 고정
- [x] JDK 21 환경에서 `flutter build apk --release --no-pub` 성공
- [x] JAVA_HOME을 Android Studio JBR 25.0.3으로 지정한 환경에서도 Gradle이 Java 21 daemon을 선택하고 `assembleRelease` 성공

JDK 21이 설치된 환경에서 사용한다. 특정 PC의 절대 JDK 경로를 프로젝트에 저장하지 않는다. Java 25 launcher의 native-access 경고는 남을 수 있으나 빌드 실패와 구분되며, JDK 21 daemon으로 릴리스 빌드가 완료됐다. 이번 변경은 빌드 JVM 설정만 수정했으며 앱 실행 테스트 또는 자동 테스트를 수행하지 않았다.

## 체크 기준

- 각 항목은 실제 구현 또는 검증이 완료된 경우에만 체크한다.
- 구현 여부와 실제 기기 검증 여부를 구분하고, 제한이나 미완료 사항은 이 문서에 기록한다.
