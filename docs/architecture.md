# Kiến trúc MediBook

Project chia theo feature, mỗi feature có 3 tầng `data` / `domain` / `presentation`.

```
lib/
├── main.dart
├── app/                  # MaterialApp, router, khung bottom-nav (shells)
├── core/                 # dùng chung: constants, theme, errors, utils, widgets
└── features/
    ├── welcome/
    ├── auth/             # đăng ký, đăng nhập, quên mật khẩu
    ├── profile/          # thông tin cá nhân, ảnh đại diện
    ├── home/             # trang chủ Khách hàng và Nhân viên
    ├── booking/          # bác sĩ, đặt lịch
    ├── appointments/     # lịch hẹn và trạng thái
    ├── staff_bookings/   # màn Lịch đặt của nhân viên
    ├── schedule/         # lịch làm việc, khung giờ
    └── notifications/    # thông báo
        ├── data/         # model, repository dùng Firebase
        ├── domain/       # entity, interface repository, logic thuần Dart
        └── presentation/ # screen, widget, controller
```

Quy tắc phụ thuộc: `presentation -> domain <- data`. Widget không gọi Firebase trực tiếp mà đi qua controller và repository.

## Lựa chọn chính
- State management: `provider` (ChangeNotifier).
- Điều hướng: `go_router`. Logic chuyển trang theo phiên và vai trò nằm ở `app/router/route_guard.dart` (thuần Dart nên viết unit test được).
- Backend: Firebase Auth (Email/Password, SĐT đổi thành `<sdt>@medibook.local`) + Cloud Firestore.
- Mở app: `/splash` khôi phục phiên, còn phiên thì vào thẳng trang chính theo vai trò, không thì về Welcome.
- Khi test, các repository Firebase được thay bằng bản giả trong `test/mocks`.

## Luồng xác thực
```
LoginForm / RegisterForm
   -> AuthController          (trạng thái loading, lỗi, người dùng hiện tại)
      -> AuthRepository       (interface, domain)
         -> FirebaseAuthRepository   (Firebase Auth + Firestore users/{uid})
```
- Hồ sơ người dùng chỉ có một bản là `AuthController.currentUser`. Sửa thông tin xong thì cập nhật lại đối tượng này, các màn hình khác tự đổi theo.
- Router chỉ chạy lại redirect khi phiên đăng nhập đổi (đăng nhập / đăng xuất), không chạy khi sửa hồ sơ.

Quên mật khẩu:
```
Đặt email khôi phục:  RecoveryEmailScreen -> AuthController -> AuthRepository
                      (xác thực lại mật khẩu -> ghi login_index/{sđt} -> gửi thư xác minh)
Đăng nhập bằng SĐT:   thử <sđt>@medibook.local, không được thì tra login_index/{sđt} lấy email thật
Quên mật khẩu:        tra login_index/{sđt} -> sendPasswordResetEmail
```

## Dữ liệu lịch hẹn
Mọi màn hình dùng chung một danh sách lịch hẹn trong `AppointmentsController`, nên số liệu ở các nơi luôn khớp nhau.

```
Firestore appointments ──> AppointmentRepository ──> AppointmentsController.items
                                                           │
          ┌────────────────────┬──────────────────────────┼─────────────────────┐
          ▼                    ▼                          ▼                     ▼
   StaffHomeScreen     StaffBookingsScreen        WorkScheduleScreen     Màn của khách hàng
   StaffHomeSummary    applyBookingFilter         buildSlots             CustomerHomeSummary
```
- Nhân viên nghe toàn bộ lịch (`start()`), khách hàng chỉ nghe lịch của mình (`start(customerId:)`). Shell gọi `start` khi vào và `stop` khi đăng xuất.
- Các con số (tổng quan hôm nay, số lịch chờ...) không lưu lại mà tính bằng hàm thuần Dart mỗi khi danh sách thay đổi.
- Xác nhận / từ chối / hủy chỉ ghi lên Firestore, giao diện đổi khi stream trả về danh sách mới.
- Lịch chờ xác nhận đã quá giờ mà chưa xử lý thì không hiện phía nhân viên nữa.
- Shell tính lại theo giờ hiện tại mỗi phút và khi mở lại app.

## Khung giờ và đặt lịch
- `WorkShift` khai báo giờ làm việc: Sáng 07:30–11:30, Chiều 13:30–17:30, mỗi khung 30 phút. Không có collection khung giờ, trạng thái khung được tính từ lịch hẹn.
- Khách hàng không được đọc lịch của người khác, nên có thêm collection `busy_slots` chỉ chứa bác sĩ + giờ để biết khung nào đã có người đặt.
- Đặt lịch dùng transaction: ghi lịch hẹn + thông báo cho nhân viên + giữ khung trong `busy_slots`. Hủy / từ chối thì xoá khung trong cùng lần ghi.
- Chống đặt trùng: khung bận không bấm được, `checkBooking` kiểm tra trước khi ghi, và Security Rules chặn ghi đè khung đã có người giữ.
- `busySlotsOf(appointments)` dùng chung cho repository thật, repository giả và script seed dữ liệu.

## Thông báo
- Nhân viên: collection `notifications`, `NotificationsController` đếm số chưa đọc. Thông báo "lịch đặt mới" được ghi cùng lúc với lịch hẹn.
- Khách hàng: `CustomerAlertsController` so trạng thái lịch với lần trước để báo xác nhận / từ chối, và hẹn giờ nhắc trước giờ khám bằng `flutter_local_notifications`. Trạng thái đã xem lưu trên máy bằng `shared_preferences`.

## Ảnh đại diện
`AvatarPicker` chọn ảnh bằng `image_picker`, `AvatarImage.process` cắt vuông và nén thành JPEG 256×256 (chạy trong isolate), sau đó `ProfileController.saveAvatar` ghi base64 vào `users/{uid}.avatar`.

## Dữ liệu mẫu
- `DemoData.build(now)` dùng cho bản demo không Firebase và cho test.
- Dữ liệu trên Firebase được ghi bằng `tool/seed_firestore.dart` (id cố định `seed_…`, `isDemo = true`).

## Hạn chế
- Nhân viên đang nghe toàn bộ collection `appointments`; với dữ liệu lớn nên giới hạn theo khoảng ngày.
- Chưa có màn quản lý bác sĩ (bác sĩ thêm trên Firebase Console).
