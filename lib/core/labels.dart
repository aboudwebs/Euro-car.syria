// Arabic labels for the status vocabularies used by the API.
// They mirror lib/status.ts of the web app, so both clients speak the same language.

const Map<String, String> orderStatusLabels = <String, String>{
  'pending': 'قيد المراجعة',
  'approved': 'تمت الموافقة',
  'shipped': 'تم الشحن',
  'delivered': 'تم التسليم',
  'cancelled': 'ملغي',
};

const Map<String, String> payMethodLabels = <String, String>{
  'sham': 'شام كاش',
  'cod': 'كاش عند الاستلام',
  'debt': 'دفتر الدين',
  'cashback': 'الكاش باك',
};

const Map<String, String> specialStatusLabels = <String, String>{
  'new': 'جديد',
  'priced': 'تم التسعير',
  'ordered': 'تم الطلب',
  'completed': 'مكتمل',
  'cancelled': 'ملغي',
};

const Map<String, String> ledgerTxLabels = <String, String>{
  'debit': 'قيد دين',
  'payment': 'تسديد',
};

const Map<String, String> tierLabels = <String, String>{
  'Bronze': 'برونزية',
  'Silver': 'فضية',
  'Gold': 'ذهبية',
  'Platinum': 'بلاتينية',
  'VIP': 'النخبة VIP',
};

const Map<String, String> roleLabels = <String, String>{
  'workshop': 'ورشة',
  'marketer': 'مسوّق',
  'admin': 'إدارة',
};

String orderStatusLabel(String status) => orderStatusLabels[status] ?? status;
String payMethodLabel(String method) => payMethodLabels[method] ?? method;
String specialStatusLabel(String status) => specialStatusLabels[status] ?? status;
String ledgerTxLabel(String type) => ledgerTxLabels[type] ?? type;
String tierLabel(String tier) => tierLabels[tier] ?? tier;
String roleLabel(String role) => roleLabels[role] ?? role;

/// Visual weight of a status; the UI maps it to a colour.
enum StatusTone { waiting, progress, success, danger }

/// Same colour logic as the web app: cancelled is red, delivered/completed green, pending/new amber, the rest blue.
StatusTone statusTone(String status) {
  switch (status) {
    case 'cancelled':
      return StatusTone.danger;
    case 'delivered':
    case 'completed':
      return StatusTone.success;
    case 'pending':
    case 'new':
      return StatusTone.waiting;
    default:
      return StatusTone.progress;
  }
}

/// A step of the workshop loyalty ladder (TIERS in lib/data.ts). Used only for the estimate on the dashboard.
class TierStep {
  const TierStep(this.name, this.minSpend, this.cashback);

  final String name;
  final double minSpend;
  final String cashback;
}

const List<TierStep> estimatedTiers = <TierStep>[
  TierStep('برونزية', 0, '2%'),
  TierStep('فضية', 1000, '4%'),
  TierStep('ذهبية', 2000, '6%'),
  TierStep('بلاتينية', 3000, '8%'),
  TierStep('النخبة VIP', 4000, '10%'),
];
