import 'package:flutter/material.dart';
import '../models/patient.dart';
import '../services/api_client.dart';
import '../services/patient_service.dart';

/// Patient data provider. Loads and caches the patient list for the
/// current facility, and offers a create entry point.
class PatientProvider extends ChangeNotifier {
  final PatientService _patientService;

  List<Patient> _patients = [];
  bool _isLoading = false;
  String? _error;

  PatientProvider({PatientService? patientService})
      : _patientService = patientService ?? PatientService(apiClient: ApiClient.instance);

  List<Patient> get patients => List.unmodifiable(_patients);
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Load all patients for the current facility.
  Future<void> loadAll() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    final result = await _patientService.getPatients();
    if (!result.success) {
      _error = result.message;
    } else {
      _patients = result.data ?? [];
    }
    _isLoading = false;
    notifyListeners();
  }

  /// Search patients by name / medical record number.
  Future<void> searchByName(String query) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    final result = await _patientService.getPatients(search: query);
    if (!result.success) {
      _error = result.message;
    } else {
      _patients = result.data ?? [];
    }
    _isLoading = false;
    notifyListeners();
  }

  /// Create a patient (demo: echoed by the demo backend).
  Future<Patient?> create({
    required String name,
    required String medicalRecordNo,
    String? gender,
    DateTime? dateOfBirth,
  }) async {
    final result = await _patientService.createPatient(
      facilityId: 'f1',
      patientCode: medicalRecordNo,
      dateOfBirth: dateOfBirth,
      gender: gender,
    );
    if (!result.success) {
      _error = result.message;
      notifyListeners();
      return null;
    }
    _patients.add(result.data!);
    notifyListeners();
    return result.data;
  }
}
