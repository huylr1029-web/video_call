# Demo gọi video Agora RTC SDK (Flutter)
## Yêu cầu
- Flutter/Dart có Android SDK, hai máy Android (hoặc một máy và một emulator có hỗ trợ camera/micro)
- Agora App ID từ https://console.agora.io
- Bật quyền Internet, Camera và Micro (AndroidManifest đã cấu hình)
- `agora_rtc_engine: 6.6.4`, `permission_handler: 12.0.3`

## Chạy
Mở terminal trong thư mục dự án, thực hiện:

```bash
flutter pub get
flutter run --dart-define=AGORA_APP_ID=APP_ID_CUA_BAN
```

Nếu dự án Agora **bật App Certificate/Token authentication**, phải tạo token RTC hợp lệ ở Agora Console (hoặc token server) cho **đúng Channel ID** và chạy:

```bash
flutter run --dart-define=AGORA_APP_ID=APP_ID_CUA_BAN --dart-define=AGORA_TOKEN=TOKEN_RTC_CUA_BAN
```

Chỉ dùng token sinh thủ công cho demo ngắn; ứng dụng thực tế phải dùng token server, không hardcode bí mật.

## Demo hai máy
1. Cài/chạy cùng ứng dụng trên hai máy Android.
2. Cả hai nhập **cùng Channel ID**, ví dụ `demo_agora`.
3. Cấp quyền micro/camera. Nhấn **Tham gia cuộc gọi** trên từng máy.
4. Khi cả hai vào cùng channel với App ID, token hợp lệ, video của đối phương hiện lên; thử tắt micro, tắt camera, đổi camera, loa ngoài.
5. Chọn **Kết thúc** để rời channel.

Đây là demo **tham gia phòng**, không có chuông gọi đến, lời mời hay trạng thái chấp nhận/từ chối. Hai máy cần chủ động tham gia cùng phòng. Demo tối ưu cho **2 người**, chỉ hiển thị người tham gia từ xa cuối cùng khi nhiều hơn 2 người vào phòng.

## Dùng chỉ một file
Nếu muốn tích hợp vào một dự án Flutter có sẵn: sao chép `lib/main.dart`, thêm 2 thư viện trong `pubspec.yaml`, khai báo quyền Android trong `AndroidManifest.xml`. Có thể chạy trực tiếp file này bằng `flutter run -t lib/main.dart ...`.

## Ghi chú
- App ID ở dự án nguồn không được sao chép vào bản phát hành để tránh mang theo cấu hình cá nhân.
- Token của Agora gắn với Channel ID; token không khớp/kết thúc hạn sẽ không kết nối được.
- Không kiểm chứng chạy/build thực tế trong môi trường tạo file nếu Flutter SDK không có sẵn.
