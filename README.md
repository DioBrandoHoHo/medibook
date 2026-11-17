# MediBook

Ứng dụng di động (Flutter) hỗ trợ đặt lịch khám bệnh. Customer xem bác sĩ, chọn ngày/khung giờ, gửi yêu cầu và theo dõi trạng thái; Staff tiếp nhận, xác nhận/từ chối lịch và theo dõi lịch làm việc.

> Trạng thái: đã có Welcome, Đăng ký/Đăng nhập, tự đăng nhập lại, phân quyền Customer/Staff, khung điều hướng 4 tab, **Trang tổng quan Staff** (tổng quan hôm nay, lịch cần xử lý, lịch sắp diễn ra, popup thông báo), **Trang Lịch đặt** (3 bộ lọc, tìm kiếm, lọc theo trạng thái, xác nhận/từ chối nhanh) Chi tiết lịch hẹn và **tab Tài khoản của Staff** (xem / sửa thông tin cá nhân, đổi mật khẩu, đăng xuất). Có thêm **tab Lịch làm việc** (bác sĩ, buổi Sáng / Chiều, khung 30 phút trống hay đã đặt). **Khu vực Khách hàng:** Trang chủ (lịch hẹn sắp tới, bác sĩ còn trống hôm nay), **Đặt lịch** (lọc theo thời gian mong muốn / chuyên khoa / tên, xem thông tin + lịch trống của bác sĩ, đặt ca 30 phút, chống đặt trùng) và tab **Cá nhân**. Tab **Lịch hẹn** của khách hàng (3 nhóm Sắp tới / Đã qua / Đã hủy, chi tiết, **hủy lịch** – lịch đã xác nhận chỉ hủy được trước giờ khám 2 giờ, hủy xong nhân viên nhận thông báo). **Quên mật khẩu** qua email khôi phục đã xác minh (vẫn đăng nhập bằng SĐT). Chưa có: quản lý bác sĩ.

## Công nghệ
| Hạng mục | Lựa chọn |
|---|---|
| Framework | Flutter 3.47.x / Dart 3.13.x (Android) |
| Backend | Firebase Auth (Email/Password) + Cloud Firestore |
| State management | `provider` |
| Routing | `go_router` (redirect theo phiên & vai trò) |

## Cài đặt và chạy
```bash
flutter pub get
flutter run
```
Nếu chưa có `google-services.json`, app vẫn build được nhưng sẽ hiện màn "Chưa cấu hình Firebase".

## Cấu hình Firebase (làm 1 lần)
1. Vào https://console.firebase.google.com → **Add project** → đặt tên (VD `medibook`) → có thể tắt Google Analytics.
2. Trong project → biểu tượng **Android** (Add app):
   - Android package name: `com.medibook.medibook` (phải đúng chính xác)
   - App nickname tuỳ ý, SHA-1 bỏ trống (đăng nhập Email/Password không cần).
   - **Download `google-services.json`** → chép vào `android/app/google-services.json`.
   - Bỏ qua các bước "Add Firebase SDK" (dự án đã cấu hình sẵn).
3. **Build → Authentication → Get started → Sign-in method → Email/Password → Enable** (không bật "Email link").
4. **Authentication → Settings → User actions → bỏ tick "Email enumeration protection"** → Save.
   Bắt buộc để phân biệt được thông báo "Số điện thoại chưa được đăng ký" và "Số điện thoại hoặc mật khẩu không chính xác" theo đặc tả. Nếu vẫn bật, cả hai trường hợp đều hiện thông báo thứ hai.
   *Đánh đổi bảo mật (đã chấp nhận):* người khác có thể dò SĐT nào đã đăng ký. Giảm thiểu: Firebase tự khoá tạm khi thử sai nhiều lần (`too-many-requests`).
5. **Build → Firestore Database → Create database** → chọn location (VD `asia-southeast1`) → *Start in production mode*.
6. Tab **Rules** → dán toàn bộ nội dung file [`firestore.rules`](firestore.rules) → **Publish**.
7. Tạo tài khoản **Staff** (không tạo được qua app – đúng đặc tả):
   - Authentication → Users → **Add user**: Email `0987654321@medibook.local` (SĐT chuẩn hoá dạng `0xxxxxxxxx` + `@medibook.local`), mật khẩu theo quy tắc.
   - Copy **User UID** vừa tạo → Firestore → collection `users` → **Add document** với Document ID = UID:
     `fullName` (string), `phone` (string, VD `0987654321`), `role` (string) = `staff`, `profileCompleted` (boolean) = `false`, `profilePromptDismissed` (boolean) = `false`.
8. Chạy lại `flutter run`.

> **Mỗi khi file `firestore.rules` thay đổi** (VD sau khi thêm Trang chủ Staff) phải làm lại bước 6: dán nội dung mới → **Publish**. Nếu chưa cập nhật, Trang chủ Staff sẽ báo "Bạn không có quyền thực hiện thao tác này." kèm nút *Thử lại*.

## Tài khoản thử
| Vai trò | Số điện thoại | Mật khẩu |
|---|---|---|
| Nhân viên | `0901234567` | (cung cấp riêng khi chấm / demo) |
| Khách hàng | `0912345678` | (cung cấp riêng khi chấm / demo) |

- Mật khẩu tài khoản demo không ghi trong kho mã để tránh lộ quyền truy cập Firebase của dự án.
- Rules không cho tự tạo nhân viên, nên muốn biến một tài khoản thành nhân viên phải vào Console → Firestore → `users` → đổi `role` thành `staff`.
- Đổi vai trò trong app: tab **Cá nhân** (khách hàng) hoặc **Tài khoản** (nhân viên) → **Đăng xuất** → đăng nhập tài khoản kia.
- Bản xem thử không cần Firebase (`flutter run -t test/demo/main_demo.dart`) có sẵn 2 tài khoản giả cùng số điện thoại, mật khẩu `Demo@123` (chỉ tồn tại trong bộ nhớ của bản xem thử).

## Dữ liệu có sẵn trên Firebase
App không còn nút "Tạo lại dữ liệu mẫu" (bỏ ngày 17/11/2026). Dữ liệu đã được ghi sẵn lên Firestore của dự án bằng công cụ `tool/seed_firestore.dart`:
- 20 bác sĩ, mỗi chuyên khoa 3–5 người (`doctors/demo_d01`…`demo_d05`, `seed_d06`…`seed_d20`), khoảng 420 lịch hẹn của các khách khác (8 lịch/ngày) rải từ 7 ngày trước tới 45 ngày sau ngày ghi, khung giữ chỗ `busy_slots` và thông báo cho nhân viên.
- Khách hàng mẫu `0912345678` có 10 lịch thuộc đủ 3 nhóm Sắp tới / Đã qua / Đã hủy (có 1 lịch năm 2027, 1 lịch chờ quá giờ, 1 lịch bị từ chối).
- Các bản ghi này có `isDemo = true` (Rules chỉ cho nhân viên ghi dữ liệu đánh dấu như vậy) và id cố định `seed_…`; app không hiển thị gì khác biệt so với lịch thật.

Ghi lại / làm mới dữ liệu (VD sau khi khoảng ngày đã trôi qua) – chạy từ thư mục gốc dự án, cần `android/app/google-services.json`:
```bash
dart run tool/seed_firestore.dart <SĐT nhân viên> <mật khẩu> <SĐT khách hàng mẫu>
# VD: dart run tool/seed_firestore.dart 0901234567 <mật khẩu nhân viên> 0912345678
```
Công cụ chỉ ghi đè các bản ghi có id cố định ở trên, không đụng lịch khách thật đặt.

## Cách thử Trang chủ Staff
1. Đăng nhập bằng tài khoản Staff → tab **Tổng quan**.
2. Bấm một lịch "Chờ xác nhận" → **Xác nhận** hoặc **Từ chối** → **Đồng ý** trong hộp thoại hỏi lại → quay lại Tổng quan: các chỉ số, thẻ "Có X lịch đặt mới cần xử lý" và danh sách sắp diễn ra đổi theo.
3. Thêm lịch tay bằng Firebase Console → Firestore → `appointments`. Lưu ý: lịch thêm tay có `doctorId` sẽ KHÔNG tự giữ khung giờ ở `busy_slots`, nên khách hàng vẫn thấy khung đó trống:
   - **Đặt lịch:** Add document (Auto-ID) với `customerId` (string), `customerName` (string), `serviceName` (string), `startAt` (timestamp), `endAt` (timestamp), `status` (string) = `pending`, `isDemo` (boolean) = `false`.
   - **Hủy lịch:** sửa trường `status` của một lịch thành `cancelled`.
   - Trang chủ đang mở sẽ tự cập nhật trong vài giây.

## Cách thử khu vực Khách hàng (Trang chủ, Đặt lịch, Cá nhân)
> Cần Publish `firestore.rules` mới nhất (đã làm ngày 17/11/2026). Bác sĩ và khung giờ bận đã có sẵn (mục "Dữ liệu có sẵn trên Firebase").
1. Đăng nhập tài khoản khách hàng → **Trang chủ**: lời chào theo họ tên, thẻ "Lịch hẹn sắp tới", 3 chỉ số, chuyên khoa, "Bác sĩ còn trống hôm nay".
2. Tab **Đặt lịch**: chọn ngày trên dải ngày, bấm **‹ ›** để sang tháng trước / sau, bấm tên tháng để mở lịch tháng và chọn tháng / năm (đặt trước tối đa 180 ngày); bấm **"Giờ bất kỳ"** để chọn một khung giờ mong muốn → danh sách chỉ còn bác sĩ trống đúng khung đó. Lọc thêm theo chuyên khoa, tìm theo tên, bật **"Còn trống"**.
3. Bấm một bác sĩ → xem thông tin, chọn ngày, buổi **Sáng / Chiều**, bấm một khung còn trống → **Đặt lịch** → kiểm tra bảng xác nhận → **Xác nhận đặt lịch**.
4. Quay lại Trang chủ: lịch vừa đặt hiện ở "Lịch hẹn sắp tới" (Chờ xác nhận); số ca trống của bác sĩ giảm 1.
5. Đăng xuất → đăng nhập Staff: lịch mới nằm ở **Lịch đặt** (Chờ xác nhận), có thông báo mới, khung ở **Lịch làm việc** thành "Chờ". Xác nhận / từ chối → đăng nhập lại khách hàng: trạng thái đổi theo; bị từ chối thì khung trống trở lại.
6. Tab **Cá nhân**: thông tin lúc đăng ký, thẻ "Lịch hẹn của tôi" (cùng số với Trang chủ), sửa thông tin, đổi mật khẩu, đăng xuất.
7. Tab **Lịch hẹn**: chọn Sắp tới / Đã qua / Đã hủy; bấm thẻ để xem Chi tiết; bấm **Hủy lịch** → đồng ý. Lịch đã xác nhận còn dưới 2 giờ trước giờ khám không có nút Hủy. Sau khi hủy: đăng nhập Staff sẽ thấy thông báo "Lịch hẹn đã hủy" ở chuông và khung giờ ở Lịch làm việc trống lại.
8. Xem nhanh không cần Firebase, mở thẳng khu vực Khách hàng: `flutter run -t test/demo/main_demo.dart --dart-define=CUSTOMER=true`.

## Cách thử Quên mật khẩu (cần Firebase thật + một email thật)
> Cần Publish lại `firestore.rules` (có thêm `login_index`). Giữ **Email enumeration protection ở trạng thái TẮT** như bước cấu hình Firebase.
1. Đăng nhập → tab **Cá nhân** (hoặc **Tài khoản**) → thẻ Bảo mật → **Email khôi phục mật khẩu** → nhập email thật + mật khẩu hiện tại → **Gửi liên kết xác minh**.
2. Mở hộp thư (xem cả thư rác) → bấm liên kết xác minh.
3. Quay lại app → app tự nhận ra email đã được xác minh (hoặc bấm **"Tôi đã xác minh – kiểm tra lại"**) và tiếp tục phiên, **không phải đăng nhập lại**. Nếu đã tắt app trước khi bấm liên kết, app chỉ hỏi lại mật khẩu ngay tại màn Email khôi phục.
4. Đăng xuất → ở form Đăng nhập bấm **"Quên mật khẩu?"** → nhập SĐT → **Gửi liên kết đặt lại mật khẩu** → mở thư, bấm liên kết, đặt mật khẩu mới.
5. Đăng nhập bằng SĐT + mật khẩu mới.
- Tài khoản chưa có email khôi phục đã xác minh sẽ được báo liên hệ phòng khám.
- Tuỳ chọn: Firebase Console → Authentication → **Templates** (sửa nội dung thư), → **Settings → Password policy** (áp quy tắc mật khẩu của app cho trang đặt lại).

## Cách thử Trang Lịch đặt
1. Tab **Lịch đặt** → chọn **Tất cả / Hôm nay / Chờ xác nhận**; số bên cạnh mỗi nút là số lịch của bộ lọc đó.
2. Lịch đang chờ có nút **Xác nhận / Từ chối** ngay trên thẻ; bấm vào thẻ để mở Chi tiết.
3. Biểu tượng kính lúp: tìm theo tên khách, dịch vụ hoặc mã lịch (gõ không dấu cũng được). Biểu tượng phễu: lọc theo trạng thái.
4. Ở Tổng quan, bấm một thẻ chỉ số (VD "Đã xác nhận") → Lịch đặt mở sẵn bộ lọc Hôm nay + trạng thái đó, số lịch bằng đúng con số trên thẻ.
5. Xem nhanh giao diện không cần Firebase (dữ liệu trong bộ nhớ, tắt app là mất): `flutter run -t test/demo/main_demo.dart`. Bản chính thức luôn là `flutter run`.

## Cách thử tab Lịch làm việc (Staff)
1. Tab **Lịch làm việc**: mỗi bác sĩ một thẻ; bấm **Sáng / Chiều** trên thẻ để xem 8 khung 30 phút của buổi đó.
   Màu khung: trắng viền xanh lá = Trống, cam = Chờ xác nhận, xanh dương = Đã đặt, xám = Đã qua.
2. Chọn ngày trên dải ngày; gõ vào ô **tìm kiếm** (tên / chuyên khoa / phòng, không cần dấu) hoặc bấm một **chuyên khoa** để thu gọn danh sách 20 bác sĩ; bật **"Chỉ bác sĩ còn trống"** để ẩn bác sĩ đã kín lịch. Thẻ tổng hợp tính theo các bác sĩ đang lọc.
3. Bấm khung có lịch để mở Chi tiết. Xác nhận / từ chối ở Lịch đặt rồi quay lại: khung đổi màu theo.
> Thêm bác sĩ thật: Firebase Console → Firestore → collection `doctors` → Add document với `name`, `specialty`, `room` (string), `isDemo` (boolean) = `false`. Lịch hẹn muốn hiện ở tab này phải có `doctorId` = id của bác sĩ.

## Cách thử tab Tài khoản (Staff)
1. Tab **Tài khoản**: họ tên và số điện thoại lúc tạo tài khoản hiện sẵn; trường chưa có ghi "Chưa cập nhật".
2. **Chỉnh sửa** → nhập email, ngày sinh (gõ `15081995` sẽ thành `15/08/1995`), giới tính → **Lưu thông tin**. Quay sang tab Tổng quan: lời chào đổi theo tên mới.
3. **Đổi mật khẩu**: nhập mật khẩu hiện tại + mật khẩu mới (đủ 4 điều kiện, khác mật khẩu cũ).
4. **Đăng xuất**: có hỏi lại; đồng ý thì về màn Đăng nhập.
> Lưu thông tin cần Rules mới: nếu báo "Bạn không có quyền thực hiện thao tác này." hãy Publish lại `firestore.rules`.

## Cấu hình an toàn
- `google-services.json`, `.env`, keystore, `firebase_options.dart` đã nằm trong `.gitignore` – **không commit**.
- Mật khẩu do Firebase Auth băm & lưu; app và Firestore không bao giờ lưu mật khẩu.
- Phân quyền nằm ở **Firestore Security Rules** (`firestore.rules`): người dùng chỉ tự tạo được hồ sơ `role = customer`, không sửa được `role`/`phone`; chỉ sửa được họ tên, email liên hệ, ngày sinh, giới tính của chính mình.
- Lịch hẹn: Customer chỉ tạo/đọc/hủy lịch của chính mình (tạo luôn ở trạng thái `pending`); Staff đọc tất cả và chỉ được đổi lịch đang chờ sang `confirmed`/`rejected`; không ai được xoá.
- Hủy lịch: Customer chỉ hủy được lịch của mình khi chưa tới giờ khám; lịch đã xác nhận phải còn ít nhất 2 giờ – Rules kiểm tra theo giờ máy chủ, không chỉ ẩn nút trong app.
- Quyền riêng tư khi đặt lịch: Customer KHÔNG đọc được lịch hẹn của người khác. Để biết bác sĩ còn trống khung nào, app đọc `busy_slots` – chỉ có bác sĩ + giờ, không có tên hay thông tin khách hàng.
- Chống đặt trùng ở phía máy chủ: lịch có bác sĩ chỉ tạo được khi trong cùng lần ghi giữ được khung `busy_slots/{doctorId}_{giờ}`; khung đã có người giữ thì Customer không ghi đè được.
- Thông báo: chỉ Staff đọc được và chỉ được đánh dấu đã đọc.
- Bác sĩ: người dùng đã đăng nhập được đọc; Staff chỉ ghi được bác sĩ mẫu; không ai được xoá.
- Quên mật khẩu: liên kết đặt lại chỉ gửi tới email mà chính chủ tài khoản đã xác minh; đặt / đổi email khôi phục phải nhập lại mật khẩu hiện tại; app không nhận hay lưu mật khẩu mới.
- Đánh đổi của bảng tra `login_index`: phải đọc được khi chưa đăng nhập (để đăng nhập bằng SĐT), nên người biết SĐT có thể tra ra email khôi phục của tài khoản đó. Chỉ đọc được từng SĐT (không liệt kê được), chỉ chủ tài khoản ghi được, và giao diện luôn che bớt email.
- Nếu lỡ lộ khoá/cấu hình: thu hồi/tạo lại trong Firebase Console.

## Kiểm thử
```bash
flutter analyze
flutter test
```
- `test/unit/` – SĐT, quy tắc mật khẩu, phân quyền route, AuthController/ProfileController, cách tính số liệu Trang chủ Staff (5 tình huống động), bộ lọc / sắp xếp / tìm kiếm / gom ngày của Lịch đặt và việc khớp số với Tổng quan, dữ liệu mẫu, controller lịch hẹn/thông báo, hồ sơ (email, ngày sinh, đồng bộ sau khi lưu), đổi mật khẩu, khung giờ làm việc (ca 30 phút, trạng thái khung, tổng hợp ngày), phần Đặt lịch của khách hàng (khung bận sinh từ lịch hẹn, trạng thái khung, lọc bác sĩ theo giờ mong muốn / chuyên khoa / tên, kiểm tra trước khi đặt, số ca trống khớp với Lịch làm việc của Staff), số liệu Trang chủ khách hàng, phân nhóm lịch hẹn của khách và quy tắc hủy lịch
- `test/widget/` – Quên mật khẩu + email khôi phục (luồng đầy đủ tới khi đăng nhập bằng mật khẩu mới), Welcome → Auth, checklist mật khẩu, xác nhận mật khẩu, ẩn/hiện, luồng đăng ký/đăng nhập đầy đủ, Trang chủ Staff (số liệu, xác nhận/từ chối, điều hướng, popup thông báo, loading/empty/error), Trang Lịch đặt (3 bộ lọc, mở chi tiết, xác nhận/từ chối, đồng bộ với Tổng quan, tìm kiếm, lọc trạng thái, mở lại app), tab Tài khoản (hiển thị thông tin lúc tạo tài khoản, sửa hồ sơ, đổi mật khẩu, đăng xuất), tab Lịch làm việc (đổi buổi, đổi ngày, lọc còn trống, đồng bộ với Lịch đặt), khu vực Khách hàng (Trang chủ, lọc bác sĩ, xem bác sĩ + đặt lịch, chống đặt trùng, đồng bộ khi Staff xác nhận / từ chối, tab Cá nhân), tab Lịch hẹn của khách hàng (3 nhóm, chi tiết, hủy lịch theo hạn 2 giờ, thông báo tới nhân viên, đồng bộ sau khi hủy)
- `test/snapshot/` – công cụ chụp ảnh giao diện bằng dữ liệu giả (tự bỏ qua khi chạy `flutter test` thông thường)
- `test/mocks/` – Fake repository (không cần Firebase khi test)

## Nơi lưu dữ liệu
| Dữ liệu | Nơi lưu |
|---|---|
| Tài khoản đăng nhập (email nội bộ `<sdt>@medibook.local`, hoặc email khôi phục thật sau khi người dùng xác minh + mật khẩu đã băm) | Firebase Authentication |
| Bảng tra `login_index/{sđt}`: uid, emails (email khôi phục đã xác minh / đang chờ), updatedAt – để đăng nhập bằng SĐT và gửi liên kết đặt lại mật khẩu | Cloud Firestore |
| Hồ sơ `users/{uid}`: fullName, phone, role, email (liên hệ), birthDate (`yyyy-MM-dd`), gender (`male`/`female`/`other`), profileCompleted, profilePromptDismissed, createdAt, updatedAt | Cloud Firestore |
| Lịch hẹn `appointments/{id}`: customerId, customerName, serviceName, startAt, endAt, status (`pending`/`confirmed`/`rejected`/`cancelled`), doctorId, doctorName (tuỳ chọn), isDemo, createdAt, updatedAt | Cloud Firestore (có bộ đệm trên máy – mở lại app vẫn còn) |
| Bác sĩ `doctors/{id}`: name, specialty, room, isDemo, experienceYears, bio, fee (3 trường sau tuỳ chọn) | Cloud Firestore |
| Khung giờ đã có người đặt `busy_slots/{doctorId}_{giờ bắt đầu (ms)}`: doctorId, startAt, appointmentId, isDemo – KHÔNG chứa thông tin khách hàng; luôn được ghi / xoá cùng lúc với lịch hẹn | Cloud Firestore |
| Thông báo cho Staff `notifications/{id}`: title, body, createdAt, isRead (dùng chung mọi Staff), appointmentId, isDemo, createdBy | Cloud Firestore |
| Phiên đăng nhập (token) – dùng để tự đăng nhập lại khi mở app, bị xoá khi đăng xuất | Firebase SDK lưu cục bộ trên máy |

## Kiến trúc
Xem [docs/architecture.md](docs/architecture.md).

## Dùng AI
Dự án dùng Claude Code (Anthropic) hỗ trợ phân tích yêu cầu, dựng khung và sinh mã các phần Welcome / Đăng ký / Đăng nhập / Quên mật khẩu / Trang chủ Staff / Trang Lịch đặt / tab Tài khoản / tab Lịch làm việc / khu vực Khách hàng (Trang chủ, Đặt lịch, Lịch hẹn, Cá nhân), kèm các file đặc tả do AI soạn theo yêu cầu. Mọi thay đổi đều được chạy `flutter analyze` và `flutter test` để kiểm chứng.
- Các file đặc tả (`*.txt`), nhật ký tiến độ từng lượt và hội thoại với AI được lưu riêng, không đưa vào kho mã này.
