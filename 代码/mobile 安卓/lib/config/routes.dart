import 'package:flutter/material.dart';
import '../models/assessment.dart';
import '../screens/login_screen.dart';
import '../screens/main_shell.dart';
import '../screens/patient_list_screen.dart';
import '../screens/patient_detail_screen.dart';
import '../screens/wound_detail_screen.dart';
import '../screens/assessment_capture_screen.dart';
import '../screens/assessment_review_screen.dart';
import '../screens/assessment_sign_screen.dart';
import '../screens/assessment_history_screen.dart';
import '../screens/assessment_record_screen.dart';
import '../screens/settings_screen.dart';

class AppRoutes {
  static Route<dynamic> generateRoute(RouteSettings settings) {
    final args = settings.arguments;
    switch (settings.name) {
      case '/':
        return _page(const LoginScreen(), settings);
      case '/home':
        return _page(const MainShell(), settings);
      case '/patients':
        return _page(const PatientListScreen(), settings);
      case '/patient-detail':
        return _page(PatientDetailScreen(patient: args as dynamic), settings);
      case '/wound-detail':
        return _page(WoundDetailScreen(woundId: args as String), settings);
      case '/capture':
        final map = args as Map<String, String>;
        return _page(AssessmentCaptureScreen(
            patientId: map['patientId']!,
            woundId: map['woundId']!,
            patientName: map['patientName']), settings);
      case '/review':
        final map = args as Map<String, dynamic>;
        return _page(AssessmentReviewScreen(
            patientId: map['patientId']!,
            woundId: map['woundId']!,
            imagePath: map['imagePath']!,
            recordTime: map['recordTime'] != null
                ? DateTime.tryParse(map['recordTime'] as String)
                : null,
            photoTimeSource: (map['photoTimeSource'] as String?) ?? 'now'), settings);
      case '/sign':
        return _page(AssessmentSignScreen(assessmentId: args as String), settings);
      case '/history':
        return _page(AssessmentHistoryScreen(woundId: args as String), settings);
      case '/assessment-record':
        return _page(AssessmentRecordScreen(assessment: args as Assessment),
            settings);
      case '/settings':
        return _page(const SettingsScreen(), settings);
      default:
        return _page(const LoginScreen(), settings);
    }
  }

  static MaterialPageRoute _page(Widget page, RouteSettings settings) =>
      MaterialPageRoute(builder: (_) => page, settings: settings);
}
