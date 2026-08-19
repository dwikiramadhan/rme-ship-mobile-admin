import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../core/network/api_config.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_client.dart';
import '../domain/doctor.dart';
import '../domain/patient.dart';

class PaginatedPatients {
  const PaginatedPatients({
    required this.data,
    required this.page,
    required this.limit,
    required this.total,
    required this.totalPages,
  });

  final List<Patient> data;
  final int page;
  final int limit;
  final int total;
  final int totalPages;
}

/// Calls the real Bayan RME patient endpoints:
/// - GET  /api/v1/patients
/// - POST /api/v1/patients
/// - GET  /api/v1/patients/{id}
/// - GET  /api/v1/patients/{id}/medical-records
/// - POST /api/v1/patients/{id}/medical-records
class PatientApi {
  PatientApi({Dio? dio}) : _dio = dio ?? DioClient.instance;

  final Dio _dio;

  /// Fetches paginated patients from GET /api/v1/patients
  Future<PaginatedPatients> getPatientsPaginated({
    int page = 1,
    int limit = 10,
    String? search,
    String? status,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'page': page,
        'limit': limit,
      };
      if (search != null && search.isNotEmpty) queryParams['search'] = search;
      if (status != null && status.isNotEmpty) queryParams['status'] = status;

      final response = await _dio.get(
        ApiConfig.patientsPath,
        queryParameters: queryParams,
      );

      final data = response.data;
      if (data is! Map<String, dynamic>) {
        throw const ApiException('Format respons pasien tidak valid.');
      }

      final result = data['result'];
      final List rawList;
      int resPage = page;
      int resLimit = limit;
      int resTotal = 0;
      int resTotalPages = 1;

      if (result is Map<String, dynamic>) {
        rawList = result['data'] is List ? result['data'] as List : [];
        resPage = (result['page'] as num?)?.toInt() ?? page;
        resLimit = (result['limit'] as num?)?.toInt() ?? limit;
        resTotal = (result['total'] as num?)?.toInt() ?? rawList.length;
        resTotalPages = (result['total_pages'] as num?)?.toInt() ?? (resTotal > 0 ? (resTotal / resLimit).ceil() : 1);
      } else if (result is List) {
        rawList = result;
        resTotal = rawList.length;
      } else {
        rawList = [];
      }

      final patients = rawList
          .whereType<Map<String, dynamic>>()
          .map((json) => Patient.fromApiJson(json))
          .toList();

      return PaginatedPatients(
        data: patients,
        page: resPage,
        limit: resLimit,
        total: resTotal,
        totalPages: resTotalPages,
      );
    } on DioException catch (e) {
      throw DioClient.mapError(e);
    }
  }

  /// Fetches medical records for a specific patient via GET /api/v1/patients/{id}/medical-records
  Future<List<Map<String, dynamic>>> getMedicalRecords(String patientId) async {
    try {
      final response = await _dio.get('${ApiConfig.patientsPath}/$patientId/medical-records');
      final data = response.data;
      if (data is Map<String, dynamic> && data['result'] is List) {
        return (data['result'] as List).whereType<Map<String, dynamic>>().toList();
      }
      return [];
    } on DioException catch (e) {
      debugPrint('getMedicalRecords error: $e');
      return [];
    }
  }

  /// Fetches all patients (convenience wrapper)
  Future<List<Patient>> getPatients({
    int page = 1,
    int limit = 50,
    String? search,
    String? status,
  }) async {
    final paginated = await getPatientsPaginated(
      page: page,
      limit: limit,
      search: search,
      status: status,
    );
    return paginated.data;
  }


  /// Fetches a single patient's full record from GET /api/v1/patients/{id}
  Future<Patient> getPatient(String id) async {
    try {
      final response = await _dio.get('${ApiConfig.patientsPath}/$id');
      final data = response.data;
      if (data is! Map<String, dynamic> || data['result'] is! Map<String, dynamic>) {
        throw const ApiException('Data pasien tidak ditemukan.');
      }
      return Patient.fromApiJson(data['result'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throw DioClient.mapError(e);
    }
  }

  /// Creates a new patient via POST /api/v1/patients
  Future<Patient> createPatient(Map<String, dynamic> body) async {
    try {
      final response = await _dio.post(
        ApiConfig.patientsPath,
        data: body,
      );
      final data = response.data;
      if (data is! Map<String, dynamic> || data['result'] is! Map<String, dynamic>) {
        throw const ApiException('Gagal mendaftarkan pasien.');
      }
      return Patient.fromApiJson(data['result'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throw DioClient.mapError(e);
    }
  }

  /// Updates an existing patient via PUT /api/v1/patients/{id}
  Future<Patient> updatePatient(String id, Map<String, dynamic> body) async {
    try {
      final response = await _dio.put(
        '${ApiConfig.patientsPath}/$id',
        data: body,
      );
      final data = response.data;
      if (data is! Map<String, dynamic> || data['result'] is! Map<String, dynamic>) {
        throw const ApiException('Gagal memperbarui data pasien.');
      }
      return Patient.fromApiJson(data['result'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throw DioClient.mapError(e);
    }
  }

  /// Adds a medical record via POST /api/v1/patients/{id}/medical-records
  Future<void> addMedicalRecord(String patientId, Map<String, dynamic> body) async {
    try {
      await _dio.post(
        '${ApiConfig.patientsPath}/$patientId/medical-records',
        data: body,
      );
    } on DioException catch (e) {
      throw DioClient.mapError(e);
    }
  }

  /// Fetches doctor list from GET /api/v1/doctors
  Future<List<Doctor>> getDoctors({
    int page = 1,
    int limit = 50,
    String? search,
    String? availability,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'page': page,
        'limit': limit,
      };
      if (search != null && search.isNotEmpty) queryParams['search'] = search;
      if (availability != null && availability.isNotEmpty) queryParams['availability'] = availability;

      final response = await _dio.get(
        ApiConfig.doctorsPath,
        queryParameters: queryParams,
      );

      final data = response.data;
      if (data is! Map<String, dynamic>) {
        throw const ApiException('Format respons dokter tidak valid.');
      }

      final result = data['result'];
      final List rawList;
      if (result is Map<String, dynamic> && result['data'] is List) {
        rawList = result['data'] as List;
      } else if (result is List) {
        rawList = result;
      } else {
        rawList = [];
      }

      return rawList
          .whereType<Map<String, dynamic>>()
          .map((json) => Doctor.fromApiJson(json))
          .toList();
    } on DioException catch (e) {
      throw DioClient.mapError(e);
    }
  }
}

