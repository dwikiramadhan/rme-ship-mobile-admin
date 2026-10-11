import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/circle_icon_button.dart';
import '../../domain/medical_history.dart';
import '../medical_history_detail_view.dart';

/// Opens the full, read-only detail of one medical record (visit) in a
/// bottom sheet. [record] is the raw record JSON from the patient detail.
Future<void> showMedicalRecordDetailSheet(
  BuildContext context,
  Map<String, dynamic> record,
) {
  final history = MedicalHistory.fromApiJson(record);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    // Comfortable reading width on tablets; full width on phones.
    constraints: const BoxConstraints(maxWidth: 720),
    builder: (_) => MedicalRecordDetailSheet(history: history),
  );
}

class MedicalRecordDetailSheet extends StatelessWidget {
  const MedicalRecordDetailSheet({super.key, required this.history});

  final MedicalHistory history;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      expand: false,
      builder: (context, scrollController) => Container(
        decoration: const BoxDecoration(
          color: AppColors.bg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              decoration: const BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                border: Border(bottom: BorderSide(color: AppColors.border)),
              ),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(top: 10, bottom: 6),
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 2, 12, 10),
                    child: Row(
                      children: [
                        Container(
                          width: 30,
                          height: 30,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: AppColors.orangeLt,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            LucideIcons.fileText,
                            size: 15,
                            color: AppColors.orange,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'Detail Rekam Medis',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.text,
                            ),
                          ),
                        ),
                        CircleIconButton(
                          icon: LucideIcons.x,
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                child: MedicalHistoryDetailView(
                  history: history,
                  embedded: true,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
