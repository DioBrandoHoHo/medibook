import '../entities/doctor.dart';

/// Nguồn dữ liệu bác sĩ (collection `doctors`).
abstract interface class DoctorRepository {
  /// Theo dõi toàn bộ bác sĩ, sắp theo tên. Dữ liệu đổi thì stream phát danh sách mới.
  Stream<List<Doctor>> watchAll();}
