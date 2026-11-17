/// Chuỗi hiển thị dùng chung. Các thông báo có ghi chú "đặc tả" phải giữ NGUYÊN VĂN.
abstract final class AppStrings {
  static const appName = 'MediBook';

  // Welcome
  static const welcomeEyebrow = 'JUST TWO CLICKS*';
  static const welcomeTagline = 'Book your Doctor any Time, anywhere.'; // đặc tả
  static const startBooking = 'Bắt đầu'; // đặc tả ghi "Bắt đầu đặt lịch" – người dùng đã duyệt rút gọn

  // Tabs
  static const tabHome = 'Trang chủ';
  static const tabBooking = 'Đặt lịch';
  static const tabAppointments = 'Lịch hẹn';
  static const tabProfile = 'Cá nhân';
  static const tabStaffBookings = 'Lịch đặt';
  static const tabSchedule = 'Lịch làm việc';
  static const tabOverview = 'Tổng quan'; // tab đầu của Staff (trang_chu.txt 2.5)
  static const tabAccount = 'Tài khoản'; // tab cuối của Staff (trang_chu.txt 2.5)

  // Trang chủ Staff (trang_chu.txt)
  static const slogan = 'Vì sức khỏe của bạn';
  static const notifications = 'Thông báo';
  static const todayOverview = 'Tổng quan hôm nay';
  static const seeDetail = 'Xem chi tiết';
  static const greeting = 'Xin chào,';
  static const greetingWish = 'Chúc bạn một ngày làm việc hiệu quả!';
  static const statTodayTotal = 'Lịch hẹn hôm nay';
  static const statPending = 'Chờ xác nhận';
  static const statConfirmed = 'Đã xác nhận';
  static const statCancelledRejected = 'Đã hủy / Từ chối';
  static String pendingNotice(int count) => 'Có $count lịch đặt mới cần xử lý'; // đặc tả 2.3
  static const noPendingNotice = 'Không có lịch đặt cần xử lý'; // đặc tả 2.3
  static const upcomingTitle = 'Lịch hẹn sắp diễn ra';
  static const seeAll = 'Xem tất cả';
  static const upcomingEmpty = 'Chưa có lịch hẹn nào sắp diễn ra';
  static const retry = 'Thử lại';
  static const loadFailed = 'Không tải được dữ liệu';
  static const cancel = 'Hủy';
  static const agree = 'Đồng ý';

  // Thông báo
  static const notificationsEmpty = 'Chưa có thông báo';
  static const markAllRead = 'Đánh dấu tất cả đã đọc';
  static const close = 'Đóng';

  // Trạng thái lịch hẹn
  static const statusPending = 'Chờ xác nhận';
  static const statusConfirmed = 'Đã xác nhận';
  static const statusRejected = 'Đã từ chối';
  static const statusCancelled = 'Đã hủy';

  // Lịch đặt (lich_dat.txt)
  static const filterAll = 'Tất cả';
  static const filterToday = 'Hôm nay';
  static const bookingsEmptyAll = 'Chưa có lịch đặt nào'; // đặc tả mục 5
  static const bookingsEmptyToday = 'Hôm nay chưa có lịch đặt nào';
  static const bookingsEmptyPending = 'Không có lịch đặt nào đang chờ xác nhận';
  static const bookingsEmptyFiltered = 'Không tìm thấy lịch đặt phù hợp';
  static const clearFilters = 'Xoá tìm kiếm và bộ lọc';
  static const search = 'Tìm kiếm';
  static const searchHint = 'Tìm theo tên khách, dịch vụ, mã lịch';
  static const closeSearch = 'Đóng tìm kiếm';
  static const clearText = 'Xoá';
  static const statusFilter = 'Lọc theo trạng thái';
  static const statusFilterHint = 'Chọn một hoặc nhiều trạng thái. Không chọn = hiện tất cả.';
  static const apply = 'Áp dụng';
  static const reset = 'Đặt lại';
  static String bookingCount(int count) => '$count lịch đặt';
  static const viewDetail = 'Xem chi tiết';

  // Xác nhận / từ chối lịch
  static const confirmDialogTitle = 'Xác nhận lịch hẹn?';
  static const rejectDialogTitle = 'Từ chối lịch hẹn?';
  static const actionIrreversible = 'Sau khi thực hiện, bạn không thể hoàn tác thao tác này.';
  static const errAlreadyHandled = 'Lịch hẹn này đã được xử lý trước đó.';
  static const noteConfirmed = 'Lịch hẹn đã được xác nhận.';
  static const noteRejected = 'Lịch hẹn đã bị từ chối.';
  static const noteCancelled = 'Khách hàng đã hủy lịch hẹn này.';
  static const notePending = 'Lịch hẹn đang chờ bạn xác nhận hoặc từ chối.';

  // Chi tiết lịch hẹn
  static const appointmentDetail = 'Chi tiết lịch hẹn';
  static const appointmentNotFound = 'Không tìm thấy lịch hẹn';
  static const fieldCode = 'Mã lịch';
  static const fieldCustomer = 'Người đặt lịch';
  static const fieldService = 'Dịch vụ khám';
  static const fieldDoctor = 'Bác sĩ';
  static const fieldDate = 'Ngày hẹn';
  static const fieldTime = 'Giờ khám';
  static const fieldStatus = 'Trạng thái';
  static const confirmAppointment = 'Xác nhận';
  static const rejectAppointment = 'Từ chối';
  static const confirmedDone = 'Đã xác nhận lịch hẹn';
  static const rejectedDone = 'Đã từ chối lịch hẹn';

  // Auth – nhãn
  static const login = 'Đăng nhập';
  static const register = 'Đăng ký';
  static const fullName = 'Họ và tên';
  static const phone = 'Số điện thoại';
  static const password = 'Mật khẩu';
  static const confirmPassword = 'Xác nhận mật khẩu';
  static const authWelcomeBack = 'Chào mừng trở lại!';
  static const authCreateAccount = 'Tạo tài khoản mới';
  static const authLoginSubtitle = 'Đăng nhập để quản lý lịch khám của bạn';
  static const authRegisterSubtitle = 'Chỉ mất chưa đầy một phút';
  static const showPassword = 'Hiện mật khẩu';
  static const hidePassword = 'Ẩn mật khẩu';

  // Quy tắc mật khẩu (đặc tả 4.2)
  static const ruleMinLength = 'Ít nhất 8 ký tự';
  static const ruleUppercase = 'Có ít nhất 1 chữ cái viết hoa (A–Z)';
  static const ruleDigit = 'Có ít nhất 1 chữ số (0–9)';
  static const ruleSpecial = 'Có ít nhất 1 ký tự đặc biệt (@, #, !, \$, %...)';

  // Auth – lỗi theo đặc tả (giữ nguyên văn)
  static const errPhoneExists = 'Số điện thoại đã được đăng ký';
  static const errPhoneNotRegistered = 'Số điện thoại chưa được đăng ký';
  static const errWrongCredentials = 'Số điện thoại hoặc mật khẩu không chính xác';
  static const errPasswordMismatch = 'Mật khẩu xác nhận không khớp';

  // Auth – lỗi kiểm tra đầu vào (đặc tả không quy định câu chữ)
  static const errFullNameRequired = 'Vui lòng nhập họ và tên';
  static const errPhoneRequired = 'Vui lòng nhập số điện thoại';
  static const errPhoneInvalid = 'Số điện thoại không hợp lệ (VD: 0912345678)';
  static const errPasswordRequired = 'Vui lòng nhập mật khẩu';
  static const errPasswordRules = 'Mật khẩu chưa đạt đủ các điều kiện bên dưới';
  static const errConfirmRequired = 'Vui lòng nhập lại mật khẩu';

  // Lỗi hệ thống
  static const errNetwork = 'Không có kết nối mạng. Vui lòng thử lại.';
  static const errTooManyRequests = 'Bạn thao tác quá nhiều lần. Vui lòng thử lại sau ít phút.';
  static const errPermission = 'Bạn không có quyền thực hiện thao tác này.';
  static const errUnknown = 'Đã có lỗi xảy ra. Vui lòng thử lại.';
  static const errAccountDataMissing =
      'Không tìm thấy dữ liệu tài khoản. Vui lòng liên hệ quản trị viên.';

  // Profile prompt (đặc tả Mục 6)
  static const profilePromptQuestion = 'Bạn có muốn cập nhật thông tin cá nhân không?';
  static const yes = 'Có';
  static const later = 'Để sau';

  // Profile
  static const profileTitle = 'Thông tin cá nhân';
  static const profileEditTitle = 'Cập nhật thông tin';
  static const profileSaved = 'Đã lưu thông tin cá nhân';
  static const save = 'Lưu thông tin';
  static const phoneReadOnlyHint = 'Số điện thoại dùng để đăng nhập, không thể thay đổi';
  static const roleCustomer = 'Khách hàng';
  static const roleStaff = 'Nhân viên';

  // Tab Lịch làm việc (lich_lam_viec.txt)
  static const shiftMorning = 'Sáng';
  static const shiftAfternoon = 'Chiều';
  static const slotFree = 'Trống';
  static const slotBooked = 'Đã đặt';
  static const slotPending = 'Chờ';
  static const slotPast = 'Đã qua';
  static const slotConflict = 'Trùng lịch';
  static const summaryFree = 'Ca trống';
  static const summaryPending = 'Chờ xác nhận';
  static const summaryBooked = 'Đã đặt';
  static const onlyFreeDoctors = 'Chỉ bác sĩ còn trống';
  static String freeOf(int free, int total) => 'Trống $free/$total';
  static String doctorCount(int count) => '$count bác sĩ';
  static const doctorsEmpty = 'Chưa có bác sĩ nào';
  static const doctorsEmptyHint =
      'Danh sách bác sĩ do phòng khám cập nhật trên hệ thống. Vui lòng thử lại sau.';
  static const noFreeDoctors = 'Không còn bác sĩ nào trống trong ngày này';
  static const scheduleSearchHint = 'Tìm bác sĩ, chuyên khoa, phòng';
  static const today = 'Hôm nay';

  // Tab Tài khoản của Staff (thong_tin.txt)
  static const accountTitle = 'Tài khoản';
  static const notUpdated = 'Chưa cập nhật';
  static const email = 'Email';
  static const birthDate = 'Ngày sinh';
  static const birthDateHint = 'dd/mm/yyyy';
  static const gender = 'Giới tính';
  static const genderMale = 'Nam';
  static const genderFemale = 'Nữ';
  static const genderOther = 'Khác';
  static const edit = 'Chỉnh sửa';
  static const optional = 'không bắt buộc';
  static const incompleteProfile = 'Hồ sơ chưa đầy đủ';
  static const incompleteProfileHint = 'Bổ sung email, ngày sinh, giới tính';
  static const securitySection = 'Bảo mật';
  static const changePassword = 'Đổi mật khẩu';
  static const changePasswordHint = 'Nên đổi mật khẩu định kỳ để bảo vệ tài khoản';
  static const currentPassword = 'Mật khẩu hiện tại';
  static const newPassword = 'Mật khẩu mới';
  static const confirmNewPassword = 'Xác nhận mật khẩu mới';
  static const passwordChanged = 'Đã đổi mật khẩu';
  static const logout = 'Đăng xuất';
  static const logoutConfirm = 'Bạn có chắc muốn đăng xuất?';
  static const errEmailInvalid = 'Email không hợp lệ';
  static const errBirthDateInvalid = 'Ngày sinh không hợp lệ (dd/mm/yyyy)';
  static const errCurrentPasswordWrong = 'Mật khẩu hiện tại không chính xác';
  static const errNewPasswordSame = 'Mật khẩu mới phải khác mật khẩu hiện tại';
  static const errSessionExpired = 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.';

  // ===== KHU VỰC KHÁCH HÀNG =====
  // Trang chủ (trang_chu.txt phần 2)
  static const customerWish = 'Hôm nay bạn muốn khám gì?';
  static const nextAppointment = 'Lịch hẹn sắp tới';
  static const noUpcoming = 'Bạn chưa có lịch hẹn nào sắp tới';
  static const noUpcomingHint = 'Chọn bác sĩ và khung giờ phù hợp chỉ trong vài bước.';
  static const bookNow = 'Đặt lịch ngay';
  static const cStatUpcoming = 'Sắp tới';
  static const cStatPending = 'Chờ xác nhận';
  static const cStatConfirmed = 'Đã xác nhận';
  static const specialties = 'Chuyên khoa';
  static const freeToday = 'Bác sĩ còn trống hôm nay';
  static const noFreeToday = 'Hôm nay không còn ca trống';
  static const pickAnotherDay = 'Xem ngày khác';
  static const otherUpcoming = 'Các lịch hẹn tiếp theo';
  static const myAppointments = 'Lịch hẹn của tôi';
  static const notePendingCustomer = 'Đang chờ nhân viên xác nhận';
  static const noteConfirmedCustomer = 'Phòng khám đã xác nhận, vui lòng đến đúng giờ';

  // Đặt lịch (dat_lich.txt)
  static const bookingTitle = 'Đặt lịch khám';
  static const bookingSubtitle = 'Chọn thời gian mong muốn để xem bác sĩ còn trống';
  static const doctorSearchHint = 'Tìm bác sĩ, chuyên khoa';
  static const wantedTime = 'Thời gian mong muốn';
  static const anyTime = 'Giờ bất kỳ';
  static const pickTime = 'Chọn giờ khám';
  static const pickTimeHint = 'Chỉ hiện các bác sĩ còn trống đúng khung giờ bạn chọn.';
  static const allSpecialties = 'Tất cả';
  static const onlyFreeShort = 'Còn trống';
  static String doctorMatch(int count) => '$count bác sĩ phù hợp';
  static String freeSlots(int count) => 'Còn $count ca trống';
  static const fullDay = 'Hết ca';
  static String freeAt(String time) => 'Trống lúc $time';
  static String nearest(String time) => 'Gần nhất $time';
  static const noDoctorMatch = 'Không có bác sĩ phù hợp';
  static const noDoctorAtTime = 'Không còn bác sĩ nào trống vào khung giờ này';
  static const noDoctorAtTimeHint = 'Hãy thử chọn giờ khác hoặc ngày khác.';
  static const doctorsEmptyCustomer = 'Phòng khám chưa cập nhật danh sách bác sĩ';
  static const clearDoctorFilters = 'Xoá bộ lọc';

  // Thông tin bác sĩ + đặt lịch
  static const doctorInfo = 'Thông tin bác sĩ';
  static const doctorNotFound = 'Không tìm thấy bác sĩ';
  static const about = 'Giới thiệu';
  static const aboutEmpty = 'Bác sĩ chưa cập nhật phần giới thiệu.';
  static String experience(int years) => '$years năm kinh nghiệm';
  static const feeLabel = 'Phí khám';
  static const pickDay = 'Chọn ngày khám';
  static const slotTaken = 'Đã đặt';
  static const slotMine = 'Của bạn';
  static const legendFree = 'Còn trống';
  static const legendSelected = 'Đang chọn';
  static const legendTaken = 'Đã có người đặt';
  static const legendMine = 'Lịch của bạn';
  static const noSlotChosen = 'Chưa chọn giờ khám';
  static const bookAction = 'Đặt lịch';
  static const bookConfirmTitle = 'Xác nhận đặt lịch';
  static const bookConfirmAction = 'Xác nhận đặt lịch';
  static const bookConfirmNote =
      'Lịch hẹn sẽ ở trạng thái Chờ xác nhận cho tới khi nhân viên phòng khám duyệt.';
  static const fieldPatient = 'Người khám';
  static const fieldRoom = 'Phòng khám';
  static const bookedDone = 'Đặt lịch thành công. Vui lòng chờ nhân viên xác nhận.';
  static const errSlotTaken = 'Khung giờ này vừa có người đặt. Vui lòng chọn giờ khác.';
  static const errSlotPast = 'Khung giờ này đã qua. Vui lòng chọn giờ khác.';
  static const errOwnOverlap = 'Bạn đã có lịch hẹn khác trong khung giờ này.';
  static const errNameMissing = 'Vui lòng cập nhật họ tên ở tab Cá nhân trước khi đặt lịch.';

  // Chọn ngày theo tháng / năm (dat_lich.txt phần bổ sung C, 17/11/2026)
  static const prevMonth = 'Tháng trước';
  static const nextMonth = 'Tháng sau';
  static const prevYear = 'Năm trước';
  static const nextYear = 'Năm sau';
  static const openCalendar = 'Mở lịch tháng';
  static const pickMonthYear = 'Chọn tháng và năm';
  static String monthShort(int month) => 'Thg $month';
  static String bookingRange(String from, String to) => 'Có thể đặt lịch từ $from đến $to.';
  static const errDayTooFar = 'Ngày này nằm ngoài thời gian cho phép đặt trước. Vui lòng chọn ngày gần hơn.';
  static String timeCleared(String time) =>
      'Khung $time của ngày này đã qua nên đã bỏ chọn giờ mong muốn.';
  static const viewAppointments = 'Xem lịch hẹn';

  // Tab Cá nhân (thong_tin.txt phần 2)
  static const personalTitle = 'Cá nhân';

  // Tab Lịch hẹn của khách hàng (lich_hen.txt)
  static const cFilterUpcoming = 'Sắp tới';
  static const cFilterPast = 'Đã qua';
  static const cFilterCancelled = 'Đã hủy';
  static const cEmptyUpcoming = 'Bạn chưa có lịch hẹn nào sắp tới';
  static const cEmptyPast = 'Chưa có lịch hẹn nào đã qua';
  static const cEmptyCancelled = 'Không có lịch hẹn nào bị hủy hoặc từ chối';
  static const cancelAppointment = 'Hủy lịch';
  static const cancelDialogTitle = 'Hủy lịch hẹn này?';
  static const keepAppointment = 'Không';
  static const cancelledDone = 'Đã hủy lịch hẹn';
  static const errCancelPast = 'Lịch hẹn đã tới giờ khám nên không thể hủy.';
  static const errCancelTooLate =
      'Lịch đã sát giờ khám (dưới 2 giờ), vui lòng liên hệ phòng khám để thay đổi.';
  static const cancelRuleHint = 'Lịch đã xác nhận chỉ hủy được trước giờ khám ít nhất 2 giờ.';
  static const noteNeverConfirmed = 'Lịch đã quá giờ mà chưa được xác nhận.';
  static const noteDoneCustomer = 'Lịch hẹn đã diễn ra.';
  static const noteRejectedCustomer =
      'Phòng khám đã từ chối lịch hẹn này. Bạn có thể đặt lịch khác.';
  static const noteCancelledCustomer = 'Bạn đã hủy lịch hẹn này.';
  static const rebook = 'Đặt lại với bác sĩ này';
  static const fieldSpecialty = 'Chuyên khoa';
  static const notifCancelledTitle = 'Lịch hẹn đã hủy';

  // Quên mật khẩu + email khôi phục (dang_ky_dang_nhap.txt – phần bổ sung)
  static const forgotPassword = 'Quên mật khẩu?';
  static const forgotTitle = 'Quên mật khẩu';
  static const forgotIntro =
      'Nhập số điện thoại đã đăng ký. Chúng tôi sẽ gửi liên kết đặt lại mật khẩu tới '
      'email khôi phục của tài khoản.';
  static const sendResetLink = 'Gửi liên kết đặt lại mật khẩu';
  static const resetSentTitle = 'Đã gửi liên kết';
  static String resetSentBody(String maskedEmail) =>
      'Liên kết đặt lại mật khẩu đã được gửi tới $maskedEmail. Mở email, bấm liên kết để '
      'đặt mật khẩu mới rồi quay lại đăng nhập. Nếu không thấy, hãy kiểm tra thư rác.';
  static const backToLogin = 'Quay lại đăng nhập';
  static const errNoRecoveryEmail =
      'Số điện thoại này chưa thiết lập email khôi phục. Vui lòng liên hệ phòng khám để được hỗ trợ.';
  static const errRecoveryNotVerified =
      'Email khôi phục của tài khoản này chưa được xác minh. Vui lòng liên hệ phòng khám để được hỗ trợ.';
  static const recoveryEmail = 'Email khôi phục mật khẩu';
  static const recoveryEmailHint = 'Dùng để lấy lại mật khẩu khi quên';
  static const recoveryIntro =
      'Khi quên mật khẩu, liên kết đặt lại sẽ được gửi tới email này. Email chỉ có hiệu lực '
      'sau khi bạn bấm liên kết xác minh trong thư.';
  static const recoveryNone = 'Chưa thiết lập';
  static const recoveryVerified = 'Đã xác minh';
  static const recoveryPending = 'Đang chờ xác minh';
  static const recoveryPendingHint =
      'Mở email và bấm liên kết xác minh, rồi quay lại app và bấm "kiểm tra lại".';
  static const recoveryCheck = 'Tôi đã xác minh – kiểm tra lại';
  static const sendVerifyLink = 'Gửi liên kết xác minh';
  static const verifySent = 'Đã gửi liên kết xác minh. Vui lòng kiểm tra email.';
  static const errEmailRequired = 'Vui lòng nhập email';
  static const errEmailInUse = 'Email này đã được dùng cho một tài khoản khác';
  static const reloginAfterVerify = 'Email khôi phục đã thay đổi. Vui lòng đăng nhập lại.';
  static const recoveryVerifiedDone = 'Đã xác minh email khôi phục.';
  static const resumeTitle = 'Xác nhận mật khẩu';
  static const resumeBody =
      'Email khôi phục vừa được xác minh. Nhập mật khẩu để tiếp tục, không cần đăng nhập lại.';
  static const resumeContinue = 'Tiếp tục';
  static const resumeSkip = 'Để sau';

  // Firebase chưa cấu hình
  static const firebaseSetupTitle = 'Chưa cấu hình Firebase';
  static const firebaseSetupBody =
      'Hãy đặt file google-services.json vào thư mục android/app/ rồi chạy lại ứng dụng. '
      'Xem hướng dẫn trong README.md.';
}
