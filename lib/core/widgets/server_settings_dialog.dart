import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../network/api_config.dart';
import '../network/dio_client.dart';
import '../theme/app_colors.dart';
import 'app_button.dart';
import 'app_text_field.dart';

/// A modal dialog allowing users / IT officers to inspect and configure the
/// backend server IP or URL dynamically at runtime, especially useful for
/// offline ship LAN / Wi-Fi deployments.
class ServerSettingsDialog extends StatefulWidget {
  const ServerSettingsDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => const ServerSettingsDialog(),
    );
  }

  @override
  State<ServerSettingsDialog> createState() => _ServerSettingsDialogState();
}

class _ServerSettingsDialogState extends State<ServerSettingsDialog> {
  late final TextEditingController _urlCtrl;
  bool _isTesting = false;
  bool? _testSuccess;
  String? _testMessage;

  @override
  void initState() {
    super.initState();
    _urlCtrl = TextEditingController(text: ApiConfig.baseUrl);
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    super.dispose();
  }

  Future<void> _testConnection() async {
    final input = _urlCtrl.text.trim();
    if (input.isEmpty) return;

    setState(() {
      _isTesting = true;
      _testSuccess = null;
      _testMessage = null;
    });

    final success = await ApiConfig.testConnection(input);

    if (!mounted) return;
    setState(() {
      _isTesting = false;
      _testSuccess = success;
      _testMessage = success
          ? 'Koneksi Berhasil (Server aktif)'
          : 'Gagal terhubung ke backend';
    });
  }

  Future<void> _save() async {
    final input = _urlCtrl.text.trim();
    final sanitized = input.isNotEmpty ? ApiConfig.sanitizeUrl(input) : null;
    await ApiConfig.saveCustomBaseUrl(sanitized);

    // Update the singleton Dio client instance baseUrl
    DioClient.instance.options.baseUrl = ApiConfig.baseUrl;

    if (!mounted) return;
    Navigator.of(context).pop();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Server backend diatur ke: ${ApiConfig.baseUrl}'),
        backgroundColor: AppColors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _resetDefault() async {
    await ApiConfig.saveCustomBaseUrl(null);
    DioClient.instance.options.baseUrl = ApiConfig.baseUrl;
    if (!mounted) return;
    setState(() {
      _urlCtrl.text = ApiConfig.defaultBaseUrl;
      _testSuccess = null;
      _testMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.border),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.skyLt,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      LucideIcons.server,
                      size: 20,
                      color: AppColors.skyBlue,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Pengaturan Server Backend',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.text,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Koneksi lokal jaringan Wi-Fi kapal',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: AppColors.sub,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(LucideIcons.x, size: 18),
                    color: AppColors.sub,
                    splashRadius: 18,
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Description
              const Text(
                'Masukkan alamat IP backend server yang terhubung di jaringan Wi-Fi yang sama.',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.sub,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 14),

              // Server URL Field
              AppTextField(
                label: 'URL / IP Server Backend',
                controller: _urlCtrl,
                placeholder: 'cth: 192.168.1.26:8080',
                onChanged: (_) {
                  if (_testSuccess != null) {
                    setState(() {
                      _testSuccess = null;
                      _testMessage = null;
                    });
                  }
                },
              ),
              const SizedBox(height: 12),

              // Test Connection status / button
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: _isTesting ? null : _testConnection,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.skyBlue,
                      side: const BorderSide(color: AppColors.skyBlue),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: _isTesting
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.skyBlue,
                            ),
                          )
                        : const Icon(LucideIcons.radio, size: 14),
                    label: Text(
                      _isTesting ? 'Menguji...' : 'Tes Koneksi',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  if (_testMessage != null)
                    Expanded(
                      child: Row(
                        children: [
                          Icon(
                            _testSuccess == true
                                ? LucideIcons.checkCircle2
                                : LucideIcons.alertCircle,
                            size: 14,
                            color: _testSuccess == true
                                ? AppColors.green
                                : AppColors.red,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              _testMessage!,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: _testSuccess == true
                                    ? AppColors.green
                                    : AppColors.red,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 20),

              // Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: _resetDefault,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.sub,
                    ),
                    child: const Text(
                      'Reset Default',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.sub,
                        ),
                        child: const Text(
                          'Batal',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                      const SizedBox(width: 8),
                      AppButton(
                        label: 'Simpan',
                        icon: LucideIcons.check,
                        onPressed: _save,
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
