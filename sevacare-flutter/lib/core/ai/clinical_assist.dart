/// On-device clinical assist for the doctor's consultation view.
///
/// Parses the IP-Staff intake vitals summary ("BP 150/95 mmHg · Sugar 210
/// mg/dL · …") plus the reported symptoms and produces short, actionable
/// insight lines the doctor can scan before the consult. Pure functions —
/// reusable by future modules (medicines, insurance risk scoring).
library;

enum InsightSeverity { alert, watch, info }

class ClinicalInsight {
  final InsightSeverity severity;
  final String text;
  const ClinicalInsight(this.severity, this.text);
}

class ClinicalAssist {
  ClinicalAssist._();

  static List<ClinicalInsight> analyze({String? vitals, String? symptoms}) {
    final insights = <ClinicalInsight>[];
    final v = vitals ?? '';
    final s = (symptoms ?? '').toLowerCase();

    // ── Blood pressure ──────────────────────────────────────────────────────
    final bp = RegExp(r'BP\s*(\d{2,3})\s*/\s*(\d{2,3})').firstMatch(v);
    if (bp != null) {
      final sys = int.parse(bp.group(1)!);
      final dia = int.parse(bp.group(2)!);
      if (sys >= 180 || dia >= 120) {
        insights.add(const ClinicalInsight(
            InsightSeverity.alert, 'Hypertensive crisis range BP — assess urgently.'));
      } else if (sys >= 140 || dia >= 90) {
        insights.add(ClinicalInsight(InsightSeverity.watch,
            'Elevated BP $sys/$dia — consider hypertension workup.'));
      } else if (sys < 90 || dia < 60) {
        insights.add(ClinicalInsight(InsightSeverity.watch,
            'Low BP $sys/$dia — check hydration and medication history.'));
      }
    }

    // ── Blood sugar ─────────────────────────────────────────────────────────
    final sugar = RegExp(r'Sugar\s*(\d{2,3})').firstMatch(v);
    if (sugar != null) {
      final value = int.parse(sugar.group(1)!);
      if (value >= 200) {
        insights.add(ClinicalInsight(InsightSeverity.alert,
            'High sugar $value mg/dL — evaluate for diabetes management.'));
      } else if (value >= 140) {
        insights.add(ClinicalInsight(InsightSeverity.watch,
            'Sugar $value mg/dL above normal — consider HbA1c.'));
      } else if (value < 70) {
        insights.add(ClinicalInsight(InsightSeverity.alert,
            'Low sugar $value mg/dL — hypoglycemia risk.'));
      }
    }

    // ── Pulse ───────────────────────────────────────────────────────────────
    final pulse = RegExp(r'Pulse\s*(\d{2,3})').firstMatch(v);
    if (pulse != null) {
      final value = int.parse(pulse.group(1)!);
      if (value > 100) {
        insights.add(ClinicalInsight(
            InsightSeverity.watch, 'Tachycardia — pulse $value bpm.'));
      } else if (value < 60) {
        insights.add(ClinicalInsight(
            InsightSeverity.watch, 'Bradycardia — pulse $value bpm.'));
      }
    }

    // ── Temperature (°F) ────────────────────────────────────────────────────
    final temp = RegExp(r'Temp\s*(\d{2,3}(?:\.\d)?)').firstMatch(v);
    if (temp != null) {
      final value = double.parse(temp.group(1)!);
      if (value >= 103) {
        insights.add(ClinicalInsight(
            InsightSeverity.alert, 'High-grade fever ${value.toStringAsFixed(1)}°F.'));
      } else if (value >= 100.4) {
        insights.add(ClinicalInsight(
            InsightSeverity.watch, 'Fever ${value.toStringAsFixed(1)}°F noted at intake.'));
      }
    }

    // ── SpO2 ────────────────────────────────────────────────────────────────
    final spo2 = RegExp(r'SpO2\s*(\d{2,3})').firstMatch(v);
    if (spo2 != null) {
      final value = int.parse(spo2.group(1)!);
      if (value < 92) {
        insights.add(ClinicalInsight(InsightSeverity.alert,
            'SpO2 $value% — low oxygen saturation, prioritise assessment.'));
      } else if (value < 95) {
        insights.add(ClinicalInsight(
            InsightSeverity.watch, 'SpO2 $value% slightly below normal.'));
      }
    }

    // ── Symptom cues ────────────────────────────────────────────────────────
    if (s.contains('chest pain') || s.contains('breathless')) {
      insights.add(const ClinicalInsight(InsightSeverity.alert,
          'Cardio-respiratory symptoms reported — rule out cardiac causes.'));
    }
    if (s.contains('fever') && s.contains('rash')) {
      insights.add(const ClinicalInsight(InsightSeverity.watch,
          'Fever with rash — consider viral exanthem / dengue screen.'));
    }
    if ((s.contains('vomit') || s.contains('loose motion') || s.contains('diarr')) &&
        !s.contains('no ')) {
      insights.add(const ClinicalInsight(InsightSeverity.info,
          'GI symptoms — check hydration status.'));
    }
    if (s.contains('follow-up') || s.contains('follow up')) {
      insights.add(const ClinicalInsight(InsightSeverity.info,
          'Follow-up visit — review previous prescription response.'));
    }

    if (insights.isEmpty && (v.isNotEmpty || s.isNotEmpty)) {
      insights.add(const ClinicalInsight(
          InsightSeverity.info, 'Vitals within normal limits at intake.'));
    }
    return insights;
  }
}
