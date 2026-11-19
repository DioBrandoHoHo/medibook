import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'app/app.dart';
import 'app/firebase_setup_screen.dart';
import 'features/appointments/data/repositories/appointment_repository_impl.dart';
import 'features/auth/data/repositories/firebase_auth_repository.dart';
import 'features/booking/data/repositories/doctor_repository_impl.dart';
import 'features/notifications/data/repositories/firestore_notification_repository.dart';
import 'features/profile/data/repositories/firebase_profile_repository.dart';

/// Điểm vào ứng dụng MediBook.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
  } catch (_) {
    // Chưa cấu hình Firebase
    runApp(const FirebaseSetupApp());
    return;
  }
  runApp(
    MediBookApp(
      authRepository: FirebaseAuthRepository(),
      profileRepository: FirebaseProfileRepository(),
      appointmentRepository: FirestoreAppointmentRepository(),
      notificationRepository: FirestoreNotificationRepository(),
      doctorRepository: FirestoreDoctorRepository(),
    ),
  );
}
