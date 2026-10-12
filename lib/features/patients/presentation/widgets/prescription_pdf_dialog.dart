import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/network/api_config.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/theme/app_colors.dart';
import 'lab_document_viewer.dart';

/// A downloaded prescription PDF.
typedef PrescriptionPdfFile = ({Uint8List bytes, String fileName});

/// Downloads the prescription PDF of a medical record.
typedef PrescriptionPdfLoader =
    Future<PrescriptionPdfFile> Function(String medicalRecordId);

/// Saves [bytes] under [fileName]; returns false when the user cancels.
typedef PrescriptionPdfSaver =
    Future<bool> Function(String fileName, Uint8List bytes);

/// The PDF is rendered by the backend (same layout as the web admin's
/// "Download Resep"), behind JWT, so it goes through the app's Dio client.
Future<PrescriptionPdfFile> _downloadWithAuth(String medicalRecordId) async {
  final res = await DioClient.instance.get<List<int>>(
    ApiConfig.medicalRecordPrescriptionPdfPath(medicalRecordId),
    options: Options(responseType: ResponseType.bytes),
  );
  return (
    bytes: Uint8List.fromList(res.data ?? const []),
    fileName:
        prescriptionFileName(res.headers.value('content-disposition')) ??
        'resep-$medicalRecordId.pdf',
  );
}

Future<bool> _saveWithPicker(String fileName, Uint8List bytes) async {
  final uri = await FilePicker.saveFile(
    dialogTitle: 'Simpan Resep',
    fileName: fileName,
    bytes: bytes,
    mimeType: 'application/pdf',
    type: FileType.custom,
    allowedExtensions: const ['pdf'],
  );
  return uri != null;
}

/// File name from a `Content-Disposition` header
/// (`attachment; filename="resep-x.pdf"` -> `resep-x.pdf`).
@visibleForTesting
String? prescriptionFileName(String? contentDisposition) {
  if (contentDisposition == null) return null;
  final match = RegExp(
    r'filename="?([^";]+)"?',
  ).firstMatch(contentDisposition);
  return match?.group(1);
}

/// Shows the prescription PDF of a medical record with a button to save it
/// to the device.
Future<void> showPrescriptionPdfDialog(
  BuildContext context, {
  required String medicalRecordId,
  PrescriptionPdfLoader? loader,
  PrescriptionPdfSaver? saver,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => PrescriptionPdfDialog(
      medicalRecordId: medicalRecordId,
      loader: loader,
      saver: saver,
    ),
  );
}

class PrescriptionPdfDialog extends StatefulWidget {
  const PrescriptionPdfDialog({
    super.key,
    required this.medicalRecordId,
    this.loader,
    this.saver,
  });

  final String medicalRecordId;

  /// Override the download / save (tests).
  final PrescriptionPdfLoader? loader;
  final PrescriptionPdfSaver? saver;

  @override
  State<PrescriptionPdfDialog> createState() => _PrescriptionPdfDialogState();
}

class _PrescriptionPdfDialogState extends State<PrescriptionPdfDialog> {
  PrescriptionPdfFile? _file;
  bool _saving = false;

  /// Loader for [LabDocumentViewer]: keeps the downloaded file so the same
  /// bytes can be saved without downloading again.
  Future<({Uint8List bytes, String? contentType})> _load(String _) async {
    final file = await (widget.loader ?? _downloadWithAuth)(
      widget.medicalRecordId,
    );
    if (mounted) setState(() => _file = file);
    return (bytes: file.bytes, contentType: 'application/pdf');
  }

  Future<void> _save() async {
    final file = _file;
    if (file == null) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);
    try {
      final saved = await (widget.saver ?? _saveWithPicker)(
        file.fileName,
        file.bytes,
      );
      if (saved) {
        messenger.showSnackBar(
          SnackBar(content: Text('Resep tersimpan: ${file.fileName}')),
        );
      }
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Gagal menyimpan resep: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final file = _file;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 720),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
              decoration: const BoxDecoration(
                color: AppColors.card2,
                border: Border(bottom: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.greenLt,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      LucideIcons.pill,
                      size: 16,
                      color: AppColors.green,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Resep Obat',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.text,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          file?.fileName ?? 'Memuat resep...',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.sub,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: file == null || _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(
                            width: 13,
                            height: 13,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.card,
                            ),
                          )
                        : const Icon(LucideIcons.download, size: 14),
                    label: const Text(
                      'Simpan',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.green,
                      foregroundColor: AppColors.card,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      LucideIcons.x,
                      size: 18,
                      color: AppColors.sub,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: MediaQuery.sizeOf(context).height * 0.72,
              child: LabDocumentViewer(
                url: ApiConfig.medicalRecordPrescriptionPdfPath(
                  widget.medicalRecordId,
                ),
                fileName: 'resep.pdf',
                loader: _load,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
