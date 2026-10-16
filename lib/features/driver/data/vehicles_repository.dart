import 'package:dio/dio.dart';

import '../../../core/constants/api_paths.dart';
import '../../../core/models/paginated.dart';
import '../../../core/network/api_client.dart';
import '../../auth/data/auth_repository.dart';
import './models/document_type_model.dart';
import './models/vehicle_model.dart';

/// Vehicles API (module 2) — vehicles CRUD, documents, document types.
class VehiclesRepository {
  VehiclesRepository(this._api, this._auth);

  final ApiClient _api;
  final AuthRepository _auth;

  // ── Vehicles ───────────────────────────────────────────────────────────────

  Future<Paginated<Vehicle>> list({
    Map<String, dynamic>? filters,
    int page = 1,
    int pageSize = 20,
  }) async {
    final data = await _api.get(
      ApiPaths.vehicles,
      query: {...?filters, 'page': page, 'page_size': pageSize},
    );
    return Paginated.fromJson(
      (data as Map).cast<String, dynamic>(),
      Vehicle.fromJson,
    );
  }

  Future<Vehicle> get(int id) async {
    final data = await _api.get(ApiPaths.vehicleById(id));
    return Vehicle.fromJson((data as Map).cast<String, dynamic>());
  }

  Future<Vehicle> create(Map<String, dynamic> body) async {
    final data = await _api.post(ApiPaths.vehicles, data: body);
    return Vehicle.fromJson((data as Map).cast<String, dynamic>());
  }

  Future<Vehicle> update(int id, Map<String, dynamic> body) async {
    final data = await _api.patch(ApiPaths.vehicleById(id), data: body);
    return Vehicle.fromJson((data as Map).cast<String, dynamic>());
  }

  Future<void> delete(int id) => _api.delete(ApiPaths.vehicleById(id));

  // ── Documents ──────────────────────────────────────────────────────────────

  /// Uploads a document as `multipart/form-data`.
  Future<VehicleDocument> uploadDocument({
    required int vehicleId,
    required String docType,
    required String filePath,
    String? expiresAt,
    void Function(int, int)? onSendProgress,
  }) async {
    final form = FormData.fromMap({
      'doc_type': docType,
      'file': await MultipartFile.fromFile(filePath),
      if (expiresAt != null && expiresAt.isNotEmpty) 'expires_at': expiresAt,
    });
    final data = await _api.upload(
      ApiPaths.vehicleUploadDocument(vehicleId),
      formData: form,
      onSendProgress: onSendProgress,
    );
    final doc = (data as Map)['document'];
    return VehicleDocument.fromJson((doc as Map).cast<String, dynamic>());
  }

  Future<void> deleteDocument({
    required int vehicleId,
    required String docType,
  }) => _api.delete(ApiPaths.vehicleDocument(vehicleId, docType));

  Future<VehicleDocument> validateDocument({
    required int vehicleId,
    required String docType,
    required bool isValidated,
    String? note,
  }) async {
    final data = await _api.post(
      ApiPaths.vehicleValidateDocument(vehicleId),
      data: {
        'doc_type': docType,
        'is_validated': isValidated,
        if (note != null && note.isNotEmpty) 'note': note,
      },
    );
    final doc = (data as Map)['document'];
    return VehicleDocument.fromJson((doc as Map).cast<String, dynamic>());
  }

  Future<Vehicle> activate(int id) async {
    final data = await _api.post(ApiPaths.vehicleActivate(id), data: const {});
    return Vehicle.fromJson((data as Map).cast<String, dynamic>());
  }

  Future<Vehicle> deactivate(int id) async {
    final data = await _api.post(
      ApiPaths.vehicleDeactivate(id),
      data: const {},
    );
    return Vehicle.fromJson((data as Map).cast<String, dynamic>());
  }

  // ── Document types ─────────────────────────────────────────────────────────

  Future<Paginated<DocumentType>> documentTypes({
    Map<String, dynamic>? filters,
  }) async {
    final data = await _api.get(
      ApiPaths.documentTypes,
      query: filters ?? const {},
    );
    return Paginated.fromJson(
      (data as Map).cast<String, dynamic>(),
      DocumentType.fromJson,
    );
  }

  Future<DocumentType> createDocumentType(Map<String, dynamic> body) async {
    final data = await _api.post(ApiPaths.documentTypes, data: body);
    return DocumentType.fromJson((data as Map).cast<String, dynamic>());
  }

  Future<DocumentType> updateDocumentType(
    int id,
    Map<String, dynamic> body,
  ) async {
    final data = await _api.patch(ApiPaths.documentTypeById(id), data: body);
    return DocumentType.fromJson((data as Map).cast<String, dynamic>());
  }

  Future<void> deleteDocumentType(int id) =>
      _api.delete(ApiPaths.documentTypeById(id));

  /// Convenience: driver's own profile (used by dashboard GPS/status flows).
  Future<void> pushLocation({required double lat, required double lng}) =>
      _auth.updateLocation(lat: lat, lng: lng);
}
