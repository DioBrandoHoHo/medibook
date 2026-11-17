import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/services/firestore_errors.dart';
import '../../domain/entities/doctor.dart';
import '../../domain/repositories/doctor_repository.dart';

/// Bác sĩ lưu trên Cloud Firestore, collection `doctors`:
/// ```
/// doctors/{id}
///   name:      string
///   specialty: string
///   room:      string
///   isDemo:    bool
///   experienceYears: int    (tuỳ chọn) số năm kinh nghiệm
///   bio:             string (tuỳ chọn) giới thiệu ngắn
///   fee:             int    (tuỳ chọn) phí khám, VND
/// ```
class FirestoreDoctorRepository implements DoctorRepository {
  FirestoreDoctorRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  static const collection = 'doctors';

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _col => _db.collection(collection);

  /// Document nhập tay thiếu tên -> bỏ qua để app không hiện thẻ trống.
  static Doctor? fromMap(String id, Map<String, dynamic> data) {
    final name = data['name'];
    if (name is! String || name.trim().isEmpty) return null;
    final specialty = data['specialty'];
    final room = data['room'];
    final experience = data['experienceYears'];
    final bio = data['bio'];
    final fee = data['fee'];
    return Doctor(
      id: id,
      name: name.trim(),
      specialty: specialty is String ? specialty.trim() : '',
      room: room is String ? room.trim() : '',
      isDemo: data['isDemo'] == true,
      // Thiếu / sai kiểu (bác sĩ nhập tay trên Console) -> coi như chưa có thông tin.
      experienceYears: experience is num && experience > 0 ? experience.toInt() : 0,
      bio: bio is String ? bio.trim() : '',
      fee: fee is num && fee > 0 ? fee.toInt() : 0,
    );
  }

  static Map<String, Object> toMap(Doctor d) => {
        'name': d.name,
        'specialty': d.specialty,
        'room': d.room,
        'isDemo': d.isDemo,
        'experienceYears': d.experienceYears,
        'bio': d.bio,
        'fee': d.fee,
      };

  @override
  Stream<List<Doctor>> watchAll() {
    return _col
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => fromMap(doc.id, doc.data()))
              .whereType<Doctor>()
              .toList()
            ..sort((a, b) => a.name.compareTo(b.name)),
        )
        .handleError((Object e) => throw mapFirestoreError(e));
  }
}
