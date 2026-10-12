import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pdfx/pdfx.dart';

import '../../../../core/network/api_config.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/theme/app_colors.dart';

/// Downloads a document (bytes + content type).
typedef LabDocumentLoader = Future<({Uint8List bytes, String? contentType})>
    Function(String url);

/// Lab result documents are served by a JWT-protected endpoint, so they are
/// downloaded through the app's Dio client (which adds the token) instead of
/// `Image.network`, which sends no Authorization header and gets a 401.
Future<({Uint8List bytes, String? contentType})> _loadWithAuth(
  String url,
) async {
  final res = await DioClient.instance.get<List<int>>(
    url,
    options: Options(responseType: ResponseType.bytes),
  );
  return (
    bytes: Uint8List.fromList(res.data ?? const []),
    contentType: res.headers.value(Headers.contentTypeHeader),
  );
}

/// Full URL of a lab document from the stored `attachment_url`
/// (e.g. `/uploads/lab-eximination/x.pdf` -> `.../view-document/x.pdf`).
String labDocumentUrl(String attachmentUrl) {
  final raw = attachmentUrl.trim();
  if (raw.startsWith('http') &&
      raw.contains('/api/v1/lab-examinations/view-document/')) {
    return raw;
  }
  final fileName = raw.split('/').last.split('?').first;
  return ApiConfig.labExaminationViewDocumentUrl(fileName);
}

/// Opens a lab result document in a dialog (PDF pages or image).
Future<void> showLabDocumentDialog(
  BuildContext context,
  String attachmentUrl, {
  String title = 'Dokumen Hasil Lab',
}) {
  final url = labDocumentUrl(attachmentUrl);
  final fileName = url.split('/').last.split('?').first;
  final isPdf = fileName.toLowerCase().endsWith('.pdf');

  return showDialog<void>(
    context: context,
    builder: (ctx) => Dialog(
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
                      color: isPdf ? AppColors.redLt : AppColors.skyLt,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      isPdf ? LucideIcons.fileText : LucideIcons.image,
                      size: 16,
                      color: isPdf ? AppColors.red : AppColors.sky,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.text,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          fileName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11, color: AppColors.sub),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(LucideIcons.x, size: 18, color: AppColors.sub),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
            ),
            // Downloads with the login token, then shows the PDF or image.
            SizedBox(
              height: MediaQuery.sizeOf(ctx).height * 0.72,
              child: LabDocumentViewer(url: url, fileName: fileName),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Shows a lab result document inline: PDFs as scrollable, zoomable pages,
/// images with pinch-to-zoom.
class LabDocumentViewer extends StatefulWidget {
  const LabDocumentViewer({
    super.key,
    required this.url,
    required this.fileName,
    this.loader,
  });

  final String url;
  final String fileName;

  /// Overrides the download (tests).
  final LabDocumentLoader? loader;

  @override
  State<LabDocumentViewer> createState() => _LabDocumentViewerState();
}

class _LabDocumentViewerState extends State<LabDocumentViewer> {
  late Future<({Uint8List bytes, String? contentType})> _download;
  PdfControllerPinch? _pdfController;

  @override
  void initState() {
    super.initState();
    _download = _start();
  }

  Future<({Uint8List bytes, String? contentType})> _start() {
    final download = (widget.loader ?? _loadWithAuth)(widget.url);
    // A failure can land before the FutureBuilder subscribes (next frame);
    // mark it handled here so it isn't reported as uncaught. The builder
    // still receives and shows the error.
    download.ignore();
    return download;
  }

  void _retry() {
    _pdfController?.dispose();
    _pdfController = null;
    final download = _start();
    setState(() {
      _download = download;
    });
  }

  @override
  void dispose() {
    _pdfController?.dispose();
    super.dispose();
  }

  bool _isPdf(Uint8List bytes, String? contentType) {
    if (contentType?.toLowerCase().contains('pdf') ?? false) return true;
    if (widget.fileName.toLowerCase().endsWith('.pdf')) return true;
    // "%PDF" magic bytes, for servers that send octet-stream.
    return bytes.length > 4 &&
        bytes[0] == 0x25 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x44 &&
        bytes[3] == 0x46;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<({Uint8List bytes, String? contentType})>(
      future: _download,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _Message(
            icon: null,
            text: 'Memuat dokumen...',
          );
        }
        final data = snapshot.data;
        if (snapshot.hasError || data == null || data.bytes.isEmpty) {
          return _Message(
            icon: LucideIcons.alertCircle,
            text: 'Gagal memuat dokumen',
            detail: _errorDetail(snapshot.error),
            onRetry: _retry,
          );
        }

        if (_isPdf(data.bytes, data.contentType)) {
          _pdfController ??= PdfControllerPinch(
            document: PdfDocument.openData(data.bytes),
          );
          return _PdfPages(controller: _pdfController!, onRetry: _retry);
        }

        return ColoredBox(
          color: Colors.black,
          child: InteractiveViewer(
            maxScale: 5,
            child: Center(
              child: Image.memory(
                data.bytes,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => const _Message(
                  icon: LucideIcons.fileX,
                  text: 'Format dokumen tidak didukung',
                  dark: true,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  String? _errorDetail(Object? error) {
    if (error is DioException) {
      final code = error.response?.statusCode;
      if (code == 404) return 'Dokumen tidak ditemukan di server.';
      if (code == 401 || code == 403) return 'Sesi tidak valid, silakan login ulang.';
      if (code == null) return 'Periksa koneksi ke server.';
    }
    return null;
  }
}

class _PdfPages extends StatefulWidget {
  const _PdfPages({required this.controller, required this.onRetry});

  final PdfControllerPinch controller;
  final VoidCallback onRetry;

  @override
  State<_PdfPages> createState() => _PdfPagesState();
}

class _PdfPagesState extends State<_PdfPages> {
  int? _pages;

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    return Stack(
      children: [
        Positioned.fill(
          child: ColoredBox(
            color: AppColors.bg,
            child: PdfViewPinch(
              controller: controller,
              backgroundDecoration: const BoxDecoration(color: AppColors.bg),
              onDocumentLoaded: (doc) => setState(() => _pages = doc.pagesCount),
              builders: PdfViewPinchBuilders<DefaultBuilderOptions>(
                options: const DefaultBuilderOptions(),
                documentLoaderBuilder: (_) =>
                    const _Message(icon: null, text: 'Membuka PDF...'),
                pageLoaderBuilder: (_) =>
                    const Center(child: CircularProgressIndicator()),
                errorBuilder: (_, error) => _Message(
                  icon: LucideIcons.fileX,
                  text: 'PDF tidak dapat dibuka',
                  detail: pdfOpenErrorDetail(error),
                  onRetry: widget.onRetry,
                ),
              ),
            ),
          ),
        ),
        // "2 / 5" page indicator.
        Positioned(
          right: 12,
          bottom: 12,
          child: ValueListenableBuilder<int>(
            valueListenable: controller.pageListenable,
            builder: (context, page, _) {
              final total = _pages ?? controller.pagesCount;
              if (total == null || total == 0) return const SizedBox.shrink();
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.text.withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$page / $total',
                  style: const TextStyle(fontSize: 11.5, color: Colors.white),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Why a downloaded PDF couldn't be rendered, in words the user can act on.
@visibleForTesting
String pdfOpenErrorDetail(Object error) {
  // The renderer is native code: after adding the package the app must be
  // stopped and started again (hot reload / restart doesn't load it).
  if (error is MissingPluginException) {
    return 'Komponen pembaca PDF belum aktif. Tutup aplikasi sepenuhnya, '
        'lalu jalankan ulang.';
  }
  return kDebugMode ? '$error' : 'File PDF rusak atau formatnya tidak didukung.';
}

class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.text,
    this.detail,
    this.onRetry,
    this.dark = false,
  });

  /// Null shows a spinner.
  final IconData? icon;
  final String text;
  final String? detail;
  final VoidCallback? onRetry;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final fg = dark ? Colors.white : AppColors.text;
    final sub = dark ? Colors.white70 : AppColors.sub;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon == null)
              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              )
            else
              Icon(icon, size: 34, color: sub),
            const SizedBox(height: 12),
            Text(text, style: TextStyle(fontSize: 13, color: fg)),
            if (detail != null) ...[
              const SizedBox(height: 4),
              Text(
                detail!,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11.5, color: sub),
              ),
            ],
            if (onRetry != null) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(LucideIcons.refreshCw, size: 14),
                label: const Text('Coba lagi'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
