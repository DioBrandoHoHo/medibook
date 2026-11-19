# MediBook

Ứng dụng đặt lịch khám bệnh viết bằng Flutter. Có 2 vai trò:
- **Khách hàng**: xem bác sĩ, chọn ngày và khung giờ còn trống để đặt lịch, theo dõi và hủy lịch hẹn.
- **Nhân viên**: xem tổng quan trong ngày, xác nhận / từ chối lịch đặt, xem lịch làm việc của bác sĩ.

## Chức năng chính

**Chung**
- Đăng ký, đăng nhập bằng số điện thoại; tự đăng nhập lại khi mở app
- Quên mật khẩu qua email khôi phục
- Xem / sửa thông tin cá nhân, đổi mật khẩu, ảnh đại diện, đăng xuất

**Khách hàng**
- Trang chủ: lịch hẹn sắp tới, chuyên khoa, bác sĩ còn trống hôm nay
- Đặt lịch: lọc theo giờ mong muốn, chuyên khoa, tên bác sĩ; chọn khung 30 phút (đặt trước tối đa 180 ngày)
- Lịch hẹn: Sắp tới / Đã qua / Đã hủy; hủy lịch (lịch đã xác nhận phải hủy trước giờ khám ít nhất 2 giờ)
- Thông báo khi lịch được xác nhận / từ chối và nhắc trước giờ khám

**Nhân viên**
- Tổng quan: số liệu hôm nay, lịch cần xử lý, lịch sắp diễn ra, thông báo
- Lịch đặt: lọc Tất cả / Hôm nay / Chờ xác nhận, tìm kiếm, lọc theo trạng thái, xác nhận / từ chối
- Lịch làm việc: các khung giờ Sáng / Chiều của từng bác sĩ (trống, chờ, đã đặt, đã qua)

## Công nghệ
| | |
|---|---|
| Framework | Flutter 3.47 / Dart 3.13 (Android) |
| Backend | Firebase Authentication + Cloud Firestore |
| State management | provider |
| Điều hướng | go_router |
| Khác | image_picker, image, flutter_local_notifications, shared_preferences |

## Chạy project
```bash
flutter pub get
flutter run
```
Cần file `android/app/google-services.json` (không có trong repo). Nếu thiếu, app vẫn chạy nhưng chỉ hiện màn "Chưa cấu hình Firebase".

App tự đăng nhập lại nếu còn phiên cũ. Muốn mở lại từ màn Welcome thì xoá dữ liệu app trước:
`adb shell pm clear com.medibook.medibook`

Có thể xem giao diện không cần Firebase (dữ liệu giả trong bộ nhớ):
```bash
flutter run -t test/demo/main_demo.dart
flutter run -t test/demo/main_demo.dart --dart-define=CUSTOMER=true   # vào thẳng phía khách hàng
```

## Cấu hình Firebase
1. Tạo project trên [Firebase Console](https://console.firebase.google.com).
2. Thêm app Android với package name `com.medibook.medibook`, tải `google-services.json` về và chép vào `android/app/`.
3. Authentication → Sign-in method → bật **Email/Password**.
4. Authentication → Settings → User actions → tắt **Email enumeration protection** (để app phân biệt được "số chưa đăng ký" và "sai mật khẩu").
5. Tạo Firestore Database (production mode), vào tab Rules, dán nội dung file `firestore.rules` rồi Publish. Mỗi lần sửa file này phải Publish lại.
6. Tài khoản nhân viên không tạo được trong app, phải tạo trên Console:
   - Authentication → Add user: email `<sđt>@medibook.local` (VD `0987654321@medibook.local`) và mật khẩu.
   - Firestore → collection `users` → thêm document có ID = UID vừa tạo, gồm: `fullName`, `phone`, `role` = `staff`, `profileCompleted` = `false`, `profilePromptDismissed` = `false`.

Đăng nhập bằng số điện thoại: app đổi số thành email `<sđt>@medibook.local` để dùng Email/Password của Firebase.

## Tài khoản thử
| Vai trò | Số điện thoại |
|---|---|
| Nhân viên | 0901234567 |
| Khách hàng | 0912345678 |

Mật khẩu gửi riêng khi demo, không ghi trong repo. Bản demo không cần Firebase dùng mật khẩu `Demo@123`.

## Dữ liệu mẫu
Dữ liệu mẫu (20 bác sĩ, khoảng 420 lịch hẹn, thông báo) được ghi lên Firestore bằng script:
```bash
dart run tool/seed_firestore.dart <SĐT nhân viên> <mật khẩu> <SĐT khách hàng mẫu>
```
Script chỉ ghi đè các bản ghi mẫu (id bắt đầu bằng `seed_` / `demo_`), không ảnh hưởng lịch thật.

## Cấu trúc dữ liệu Firestore
| Collection | Nội dung |
|---|---|
| `users/{uid}` | họ tên, SĐT, vai trò, email, ngày sinh, giới tính, ảnh đại diện (base64) |
| `appointments/{id}` | khách hàng, dịch vụ, bác sĩ, giờ bắt đầu / kết thúc, trạng thái |
| `doctors/{id}` | tên, chuyên khoa, phòng, kinh nghiệm, phí khám |
| `busy_slots/{doctorId}_{giờ}` | khung giờ đã có người đặt (không chứa thông tin khách) |
| `notifications/{id}` | thông báo cho nhân viên |
| `login_index/{sđt}` | tra SĐT ra email khôi phục để đăng nhập / quên mật khẩu |

Ảnh đại diện lưu luôn trong Firestore (JPEG 256×256) vì Firebase Storage cần gói trả phí.

## Bảo mật
- `google-services.json`, `.env`, keystore đã có trong `.gitignore`.
- Mật khẩu do Firebase Auth quản lý, app không lưu mật khẩu.
- Phân quyền viết trong `firestore.rules`:
  - Người dùng tự đăng ký chỉ được làm khách hàng, không sửa được vai trò và SĐT.
  - Khách hàng chỉ đọc / tạo / hủy lịch của mình; nhân viên chỉ được xác nhận hoặc từ chối lịch đang chờ.
  - Khách hàng không đọc được lịch của người khác, chỉ đọc `busy_slots` để biết khung nào còn trống.
  - Đặt trùng giờ bị chặn ở phía server bằng `busy_slots`.

## Kiểm thử
```bash
flutter analyze
flutter test
```
- `test/unit/` – logic thuần Dart (validate, phân quyền route, tính số liệu, lọc lịch, khung giờ, hủy lịch, ảnh đại diện, thông báo...)
- `test/widget/` – các màn hình và luồng chính của cả hai vai trò
- `test/mocks/` – repository giả thay cho Firebase khi test

## Kiến trúc
Xem [docs/architecture.md](docs/architecture.md).

## Sử dụng AI
Dự án có dùng Claude Code (Anthropic) để hỗ trợ phân tích yêu cầu, gợi ý cấu trúc project và sinh một phần mã. Các thay đổi đều được kiểm tra lại bằng `flutter analyze` và `flutter test`.
