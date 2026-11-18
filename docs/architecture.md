# Kiến trúc MediBook

Feature-first, mỗi feature chia 3 tầng:

```
lib/
├── main.dart                 # entry point
├── app/                      # cấu hình cấp ứng dụng
│   ├── app.dart              # MaterialApp, theme
│   ├── router/               # tên route + router
│   └── shells/               # khung bottom-nav Customer / Staff
├── core/                     # dùng chung mọi feature
│   ├── constants/            # chuỗi, hằng số
│   ├── theme/                # màu, theme
│   ├── errors/               # AppFailure
│   ├── utils/                # validators...
│   ├── services/             # storage, connectivity, logger
│   └── widgets/              # widget dùng chung
└── features/
    ├── welcome/
    ├── auth/                 # đăng ký, đăng nhập, vai trò
    ├── profile/              # thông tin cá nhân (chung 2 vai trò)
    ├── home/                 # trang chủ Customer và Staff
    ├── booking/              # bác sĩ, chọn ngày/giờ (Customer)
    ├── appointments/         # lịch hẹn và trạng thái
    ├── staff_bookings/       # Staff xử lý lịch đặt
    └── schedule/             # lịch làm việc / khung giờ
        ├── data/             # datasources, models, repositories impl
        ├── domain/           # entities, repository interfaces
        └── presentation/     # screens, widgets, controllers
```

Quy tắc phụ thuộc: `presentation -> domain <- data`. Widget không gọi backend trực tiếp.

## Quyết định đã chốt (2026-11-13)
- State management: `provider` (ChangeNotifier) – `AuthController`, `ProfileController`
- Routing: `go_router` – logic redirect nằm trong `app/router/route_guard.dart` (thuần Dart, có unit test)
- Backend: Firebase Auth (Email/Password, SĐT quy đổi `<sdt>@medibook.local`) + Cloud Firestore
- Hỏi cập nhật hồ sơ: chỉ khi `profileCompleted == false` **và** `profilePromptDismissed == false` (đã bấm "Để sau" thì không hỏi lại)
- Mở app: `/splash` khôi phục phiên → còn phiên vào thẳng trang chính theo vai trò, không thì Welcome
- Đăng xuất: `AuthController.logout()` – nút ở tab Tài khoản (Staff) và tab Cá nhân (Customer)

## Lịch làm việc – khung giờ được tính, không lưu (2026-11-15, lich_lam_viec.txt)
```
Firestore: doctors ──snapshots()──> DoctorRepository.watchAll() ──> DoctorsController ─┐
Firestore: appointments ──> AppointmentsController.items (danh sách chung) ───────────┤
                                                                                      ▼
                                   WorkScheduleScreen: buildSlots(doctorId, day, shift, items, now)
                                                       summarizeDay(doctors, day, items, now)
```
- `WorkShift` (`features/schedule/domain/`) là nơi DUY NHẤT khai báo giờ làm việc: Sáng 07:30–11:30, Chiều 13:30–17:30, khung 30 phút.
- Không có collection khung giờ: `TimeSlot.state` (free / pending / booked / past) suy ra từ lịch hẹn có `doctorId` trùng và còn hiệu lực. Vì vậy tab này luôn khớp với Lịch đặt và Tổng quan.
- `Doctor` + `DoctorRepository` đặt ở `features/booking/` để phần Đặt lịch của Customer dùng lại.
- Màn hình chỉ giữ trạng thái giao diện: ngày đang xem, buổi đang xem của từng bác sĩ, bật/tắt lọc "còn trống".

## Khu vực Khách hàng – đặt lịch không lệch dữ liệu (2026-11-16, dat_lich.txt, trang_chu.txt phần 2)
```
Firestore: appointments (lịch của TÔI) ─> AppointmentRepository.watchMine(uid) ─> AppointmentsController.items ─┐
Firestore: doctors ────────────────────> DoctorRepository.watchAll() ─────────> DoctorsController ─────────────┤
Firestore: busy_slots (bác sĩ + giờ) ──> AppointmentRepository.watchBusySlots() ─> BusySlotsController.ids ────┤
                                                                                                                ▼
     availability.dart (thuần Dart): buildBookSlots · freeSlotStarts · applyDoctorFilter · checkBooking
     CustomerHomeSummary.from(items, now)
                                                                                                                ▼
     CustomerHomeScreen · BookingScreen · DoctorDetailScreen · ProfileScreen · chấm số tab Lịch hẹn
```
- **Vì sao có `busy_slots`:** Rules chỉ cho Customer đọc lịch hẹn của chính mình (quyền riêng tư), nên không thể tính lịch trống của bác sĩ từ `appointments`. `busy_slots` là bản chiếu KHÔNG có thông tin khách hàng của các lịch còn hiệu lực.
- **Không lệch với `appointments`:** mọi thao tác làm đổi việc giữ khung đều ghi hai nơi trong CÙNG một lần ghi – đặt lịch (giao dịch: lịch hẹn + thông báo Staff + giữ khung), từ chối / hủy (đổi trạng thái + xoá khung); dữ liệu có sẵn ghi bằng `tool/seed_firestore.dart` cũng ghi khung từ `busySlotsOf`. Hàm `busySlotsOf(appointments)` là nơi DUY NHẤT quyết định lịch nào giữ khung nào; repository Firestore và repository giả của bộ test cùng dùng nó.
- **Chống đặt trùng 3 lớp:** khung bận không bấm được → `checkBooking` + giao dịch đọc khung trước khi ghi → Security Rules (id khung duy nhất, Customer không có quyền update).
- `AppointmentsController` dùng chung hai vai trò: Staff `start()` nghe tất cả, Customer `start(customerId:)` chỉ nghe lịch của mình. `CustomerShell` / `StaffShell` gọi `start` khi vào và `stop` khi rời (đăng xuất) nên dữ liệu người trước không lọt sang người sau.
- Ca làm việc, độ dài khung dùng chung `WorkShift` với tab Lịch làm việc → số ca trống Customer thấy = số khung Trống Staff thấy (có unit test so sánh).
- Bộ lọc của tab Đặt lịch (từ khoá, chuyên khoa, ngày, giờ mong muốn, "còn trống") là trạng thái giao diện ở `CustomerNavController`; Trang chủ dùng nó để mở Đặt lịch với chuyên khoa lọc sẵn.
- Tab Cá nhân dùng chung khung `AccountView` với tab Tài khoản của Staff; chỉ thêm thẻ "Lịch hẹn của tôi" (tính bằng `CustomerHomeSummary`, cùng hàm với Trang chủ).

## Quên mật khẩu qua email khôi phục (2026-11-16, dang_ky_dang_nhap.txt phần bổ sung)
```
Đặt email khôi phục (đang đăng nhập):
  RecoveryEmailScreen -> AuthController.requestRecoveryEmail -> AuthRepository
     1. xác thực lại mật khẩu hiện tại   2. ghi login_index/{sđt}.emails   3. verifyBeforeUpdateEmail(email)
  Người dùng bấm liên kết trong thư -> email đăng nhập trên Firebase Auth đổi thành email thật.

Đăng nhập bằng SĐT:  thử <sđt>@medibook.local  --không được-->  tra login_index/{sđt}  -->  thử từng email thật
Quên mật khẩu:       ForgotPasswordScreen -> tra login_index/{sđt} -> sendPasswordResetEmail(email đã xác minh)
```
- Người dùng luôn đăng nhập bằng SĐT; `login_index` chỉ là bảng tra SĐT → email đăng nhập thật. Tài khoản chưa đặt email khôi phục không có bản ghi và đi đúng luồng cũ.
- Hồ sơ, vai trò, lịch hẹn gắn với `uid` nên không đổi khi email đăng nhập đổi.
- Email khôi phục (trên Firebase Auth) tách riêng với email liên hệ `users/{uid}.email`.

## Hồ sơ người dùng – một nguồn duy nhất (2026-11-15, thong_tin.txt)
```
Đăng ký / Console ──> Firestore users/{uid} ──login / restoreSession──> AuthController.currentUser
                              ▲                                              │ (một đối tượng AppUser)
                              │ updateProfile()                ┌─────────────┼──────────────┐
                     ProfileController.save()                  ▼             ▼              ▼
                              ▲                        StaffAccountScreen  ProfileEdit   StaffHomeHeader
                              └──────── ghi xong mới updateCurrentUser() ─── (điền sẵn)   ("Xin chào, …")
```
- Không màn hình nào giữ bản sao họ tên / SĐT / email: sửa ở Cập nhật thông tin thì tab Tài khoản và lời chào Tổng quan đổi ngay.
- `users/{uid}` có thêm `email` (liên hệ), `birthDate` (`yyyy-MM-dd`), `gender` – tuỳ chọn; `phone` và `role` không sửa được từ app (Rules chặn).
- Ảnh đại diện (18/11/2026): `users/{uid}.avatar` = JPEG 256×256 base64. `AvatarPicker` (interface; bản thật dùng `image_picker`
  + `compute(AvatarImage.process)`) chọn và xử lý ảnh → `ProfileController.saveAvatar` ghi Firestore trước, thành công mới
  `AuthController.updateCurrentUser` → widget `UserAvatar` ở thẻ tài khoản, `StaffHomeHeader` (NV + KH), màn Cập nhật thông tin đổi theo.
- Đổi mật khẩu: `AuthRepository.changePassword` (Firebase xác thực lại mật khẩu hiện tại rồi mới đổi). Đăng xuất: `AuthController.logout()`.
- Router chỉ chạy lại redirect khi PHIÊN đổi (`AuthController.sessionChanges`), không chạy khi sửa hồ sơ – tránh việc tải lại route hoàn tác thao tác quay lại sau khi lưu.

## Luồng dữ liệu xác thực
```
Widget (LoginForm/RegisterForm)
   -> AuthController (provider)          // trạng thái loading, lỗi
      -> AuthRepository (interface)      // domain
         -> FirebaseAuthRepository       // data: Firebase Auth + Firestore users/{uid}
```
Khi test, `FakeAuthRepository` (test/mocks) thay cho Firebase.

## Trang chủ Staff – một nguồn dữ liệu duy nhất (2026-11-14)
```
Firestore: appointments ──snapshots()──> FirestoreAppointmentRepository.watchAll()
                                              │  Stream<List<Appointment>>
                                              ▼
                                   AppointmentsController      // giữ MỘT danh sách lịch hẹn
                                              │
        ┌─────────────────────────────────────┼─────────────────────────────┐
        ▼                                     ▼                             ▼
StaffHomeScreen                      StaffBookingsScreen         AppointmentDetailScreen
 StaffHomeSummary.from(items, now)    applyBookingFilter(...)      byId(id) + confirm()/reject()
  ├─ 4 chỉ số hôm nay                                                    │ updateStatus()
  ├─ số lịch chờ xử lý (mọi ngày)                                        ▼
  └─ 3 lịch sắp diễn ra                                      Firestore: appointments
```
- Không có biến đếm nào được lưu: mọi con số là kết quả của hàm thuần Dart `StaffHomeSummary.from` (`features/home/domain/`), tính lại mỗi khi stream phát danh sách mới.
- Xác nhận/Từ chối chỉ **ghi vào Firestore**; giao diện đổi vì Firestore đẩy danh sách mới về, không tự cộng trừ.
- Thông báo: `notifications` → `NotificationsController` (số chưa đọc = đếm từ danh sách). Thông báo "lịch đặt mới" được ghi cùng lúc với lịch hẹn trong một batch (`AppointmentRepository.create`).
- `AppointmentsController` / `NotificationsController` khai báo ở `app.dart` nhưng chỉ bắt đầu lắng nghe khi `StaffShell` gọi `start()` và dừng khi Staff đăng xuất (`stop()`).
- **Trang Lịch đặt (2026-11-15):** không có nguồn dữ liệu riêng. `applyBookingFilter(items, filter, now, statuses:, query:)` (`features/appointments/domain/booking_filter.dart`, thuần Dart) lọc + sắp xếp theo `DateTime`; `groupBookingsByDay` gom theo ngày để hiện tiêu đề. Số trên từng nút lọc và chấm số trên tab Lịch đặt cũng đếm từ `AppointmentsController.items`.
- Xác nhận / Từ chối ở thẻ Lịch đặt và ở màn Chi tiết dùng chung `runAppointmentAction` (hỏi lại → `controller.confirm/reject` → thông báo). Tên + màu trạng thái dùng chung `StatusStyle`.
- `StaffShell` gọi `refreshClock()` mỗi phút, khi đổi tab và khi mở lại app từ nền, nên "Hôm nay" và "sắp diễn ra" luôn theo giờ hiện tại.
- `StaffNavController` (`app/shells/`) giữ tab đang chọn + bộ lọc màn Lịch đặt (bộ lọc chính, lọc trạng thái, từ khoá), để Trang chủ chuyển tab kèm bộ lọc ("Xem chi tiết" → Hôm nay, thẻ chờ xử lý → Chờ xác nhận, "Xem tất cả" → Tất cả).
- Thời gian: `clock` truyền vào `MediBookApp` (mặc định giờ thiết bị, test dùng giờ cố định). Số liệu được tính lại khi quay về tab Tổng quan và khi mở lại app từ nền.
- Dữ liệu mẫu: `DemoData.build(now)` chỉ dùng cho bản xem thử không Firebase và test. Dữ liệu trên Firebase thật ghi một lần bằng `tool/seed_firestore.dart` (sinh bởi `tool/seed_data.dart`, id cố định `seed_…`, `isDemo = true`). Nút "Tạo lại dữ liệu mẫu" trong app đã bỏ ngày 17/11/2026.
- Giới hạn đã biết: Staff lắng nghe toàn bộ collection `appointments` (đủ cho quy mô đồ án; dữ liệu lớn cần giới hạn theo khoảng ngày).
