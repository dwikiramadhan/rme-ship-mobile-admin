import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/clean_text_helper.dart';
import '../../../core/widgets/screen_header.dart';
import '../../patients/data/patient_repository.dart';
import '../../patients/domain/lab_order.dart';
import '../../patients/domain/patient.dart';
import '../../patients/domain/prescription_item.dart';

enum NotificationRole { doctor, pharmacy, lab }

/// Clean, informative, and beautifully styled notification list without search and tabs.
class NotificationsView extends ConsumerStatefulWidget {
  const NotificationsView({
    super.key,
    required this.role,
    required this.onTapItem,
    this.onMarkSeen,
  });

  final NotificationRole role;
  final void Function(BuildContext context, Patient patient, bool isLab) onTapItem;
  final void Function(Patient patient, bool isLab)? onMarkSeen;

  @override
  ConsumerState<NotificationsView> createState() => _NotificationsViewState();
}

class _NotificationsViewState extends ConsumerState<NotificationsView> {
  List<Patient> _filterRolePatients(List<Patient> all) {
    switch (widget.role) {
      case NotificationRole.doctor:
        return all.where((p) {
          final isWaitingDoc = p.status == PatientStatus.menungguDokter;
          final isLabReady = p.labOrder?.status == LabOrderStatus.selesai;
          return isWaitingDoc || isLabReady;
        }).toList();
      case NotificationRole.pharmacy:
        return all.where((p) {
          return p.statusPenanganan == 'Menunggu Obat' ||
              p.resepStatus == ResepStatus.baru ||
              (p.resep.isNotEmpty && p.resepStatus != ResepStatus.selesai);
        }).toList();
      case NotificationRole.lab:
        return all.where((p) {
          return p.statusPenanganan == 'Menunggu Lab' ||
              (p.labOrder != null && p.labOrder!.status == LabOrderStatus.baru);
        }).toList();
    }
  }

  void _markAllRead() {
    switch (widget.role) {
      case NotificationRole.doctor:
        ref.read(notificationsProvider.notifier).markAllDoctorSeen();
        break;
      case NotificationRole.pharmacy:
        ref.read(notificationsProvider.notifier).markAllPharmacySeen();
        break;
      case NotificationRole.lab:
        ref.read(notificationsProvider.notifier).markAllLabSeen();
        break;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Semua notifikasi ditandai telah dibaca'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _syncNotifications() {
    ref.read(notificationsProvider.notifier).catchUpSync();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Menyinkronkan notifikasi dengan server kapal...'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
  }

  bool _isUnread(Patient p, bool isLab) {
    switch (widget.role) {
      case NotificationRole.doctor:
        return isLab ? !p.dilihatDokterLab : !p.dilihatDokter;
      case NotificationRole.pharmacy:
        return !p.dilihatPharmacy;
      case NotificationRole.lab:
        return !p.dilihatLab;
    }
  }

  @override
  Widget build(BuildContext context) {
    final allNotifs = ref.watch(notificationsProvider);
    final roleNotifs = _filterRolePatients(allNotifs);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ScreenHeader(
          title: 'Notifikasi',
          subtitle: '${roleNotifs.length} pemberitahuan masuk',
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(LucideIcons.refreshCw, size: 18),
                tooltip: 'Sinkronisasi Notifikasi',
                color: AppColors.sub,
                onPressed: _syncNotifications,
              ),
              const SizedBox(width: 6),
              OutlinedButton.icon(
                onPressed: roleNotifs.isEmpty ? null : _markAllRead,
                icon: const Icon(LucideIcons.checkCheck, size: 16),
                label: const Text('Tandai Semua Dibaca'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.orange,
                  side: BorderSide(
                    color: roleNotifs.isEmpty
                        ? AppColors.border
                        : AppColors.orange.withValues(alpha: 0.5),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  textStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Notifications List
        Expanded(
          child: roleNotifs.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  itemCount: roleNotifs.length,
                  itemBuilder: (context, index) {
                    final patient = roleNotifs[index];
                    final isLab = patient.labOrder?.status == LabOrderStatus.selesai;
                    final isUnread = _isUnread(patient, isLab);

                    return _NotificationCard(
                      patient: patient,
                      role: widget.role,
                      isLabResult: isLab,
                      isUnread: isUnread,
                      onTap: () => widget.onTapItem(context, patient, isLab),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: AppColors.card2,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.border),
              ),
              child: const Icon(
                LucideIcons.bellOff,
                size: 28,
                color: AppColors.sub,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Tidak Ada Notifikasi',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Semua antrian pasien dan tindakan telah selesai atau dibaca.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.sub,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Clean, informative, and visually appealing card for each notification.
class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.patient,
    required this.role,
    required this.isLabResult,
    required this.isUnread,
    required this.onTap,
  });

  final Patient patient;
  final NotificationRole role;
  final bool isLabResult;
  final bool isUnread;
  final VoidCallback onTap;

  String _getInitials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts[0].isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  Widget _vitalChip(String label, String value, {bool isAlert = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isAlert ? AppColors.redLt : AppColors.card,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(
          color: isAlert ? AppColors.red.withValues(alpha: 0.3) : AppColors.border,
        ),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(
          fontSize: 11,
          fontWeight: isAlert ? FontWeight.w700 : FontWeight.w500,
          color: isAlert ? AppColors.red : AppColors.text,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cleanName = CleanTextHelper.cleanName(patient.nama, fallback: 'Pasien');
    final rm = patient.registerNo.isNotEmpty ? patient.registerNo : patient.nik;

    Color themeColor;
    Color themeBg;
    IconData themeIcon;
    String statusLabel;

    if (role == NotificationRole.doctor) {
      if (isLabResult) {
        themeColor = AppColors.purple;
        themeBg = AppColors.purpleLt;
        themeIcon = LucideIcons.flaskConical;
        statusLabel = 'Hasil Lab Selesai';
      } else {
        themeColor = AppColors.blue;
        themeBg = AppColors.blueLt;
        themeIcon = LucideIcons.stethoscope;
        statusLabel = 'Menunggu Dokter';
      }
    } else if (role == NotificationRole.pharmacy) {
      themeColor = AppColors.orange;
      themeBg = AppColors.orangeLt;
      themeIcon = LucideIcons.pill;
      statusLabel = 'Resep Baru';
    } else {
      themeColor = AppColors.purple;
      themeBg = AppColors.purpleLt;
      themeIcon = LucideIcons.flaskConical;
      statusLabel = 'Order Lab';
    }

    final hasVitals = !patient.vitals.isEmpty;
    final hasComplaint = patient.keluhanUtama.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isUnread ? Colors.white : AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isUnread ? AppColors.blue.withValues(alpha: 0.35) : AppColors.border,
          width: isUnread ? 1.2 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isUnread ? 0.04 : 0.015),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Avatar + Name & Demographics + Status Badge + Time + Chevron
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Avatar
                    Container(
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: themeBg,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        _getInitials(cleanName),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: themeColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Patient Information
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  cleanName,
                                  style: const TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.text,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (isUnread) ...[
                                const SizedBox(width: 6),
                                Container(
                                  width: 7,
                                  height: 7,
                                  decoration: const BoxDecoration(
                                    color: AppColors.blue,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            [
                              if (rm.isNotEmpty) rm,
                              '${patient.jk == Gender.l ? 'L' : 'P'} • ${patient.umur} th',
                              if (patient.poliName != null && patient.poliName!.isNotEmpty)
                                patient.poliName!,
                            ].join(' · '),
                            style: const TextStyle(fontSize: 12, color: AppColors.sub),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Badge & Timestamp
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: themeBg,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(themeIcon, size: 12, color: themeColor),
                              const SizedBox(width: 4),
                              Text(
                                statusLabel,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: themeColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          patient.waktuMasuk.isNotEmpty ? patient.waktuMasuk : 'Baru saja',
                          style: const TextStyle(fontSize: 11, color: AppColors.sub),
                        ),
                      ],
                    ),
                    const SizedBox(width: 6),
                    const Icon(LucideIcons.chevronRight, size: 16, color: AppColors.sub),
                  ],
                ),

                // Clinical Context (Informative Highlights)
                if (hasComplaint || hasVitals || isLabResult || patient.resep.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.card2.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (isLabResult && patient.labOrder != null) ...[
                          Row(
                            children: [
                              const Icon(LucideIcons.flaskConical, size: 13, color: AppColors.purple),
                              const SizedBox(width: 5),
                              Expanded(
                                child: Text(
                                  'Pemeriksaan Lab: ${patient.labOrder!.jenis}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.text,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ] else if (role == NotificationRole.pharmacy && patient.resep.isNotEmpty) ...[
                          Row(
                            children: [
                              const Icon(LucideIcons.pill, size: 13, color: AppColors.orange),
                              const SizedBox(width: 5),
                              Expanded(
                                child: Text(
                                  '${patient.resep.length} Obat: ${patient.resep.map((r) => r.obat).take(3).join(', ')}${patient.resep.length > 3 ? '...' : ''}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.text,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ] else if (hasComplaint) ...[
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Keluhan: ',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.sub,
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  patient.keluhanUtama,
                                  style: const TextStyle(fontSize: 12, color: AppColors.text),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],

                        // Vital Signs
                        if (hasVitals) ...[
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              if (patient.vitals.tekananDarah.isNotEmpty)
                                _vitalChip('TD', patient.vitals.tekananDarah),
                              if (patient.vitals.nadi.isNotEmpty)
                                _vitalChip('Nadi', '${patient.vitals.nadi}x/m'),
                              if (patient.vitals.suhu.isNotEmpty)
                                _vitalChip(
                                  'Suhu',
                                  '${patient.vitals.suhu}°C',
                                  isAlert: (double.tryParse(patient.vitals.suhu) ?? 0) >= 37.8,
                                ),
                              if (patient.vitals.spo2.isNotEmpty)
                                _vitalChip(
                                  'SpO2',
                                  '${patient.vitals.spo2}%',
                                  isAlert: (int.tryParse(patient.vitals.spo2) ?? 100) <= 94,
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
