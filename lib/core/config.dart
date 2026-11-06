// Static configuration and reference data shared by the whole app.
//
// Anything that mirrors the web app (brand lists, governorates, limits) is kept here in one place so the
// two clients stay consistent. The server remains the authority for every rule below.

/// Base URL of the EURO CARS API. Override per build with --dart-define=EURO_API_URL=https://example.com
const String apiBase = String.fromEnvironment(
  'EURO_API_URL',
  defaultValue: 'https://control-panel-euro-cars.onrender.com',
);

/// Support WhatsApp number (same number the web account page links to).
const String supportWhatsApp = '963982026134';
const String supportMessage = 'أريد التواصل مع دعم اليورو';
const String developerName = 'Aboud Web';
const String developerUrl = 'https://aboudweb.onrender.com';

/// The hosted API sleeps when idle (cold start), so requests get a generous timeout.
const Duration requestTimeout = Duration(seconds: 60);
const Duration uploadTimeout = Duration(seconds: 120);

/// Limits enforced by the API (see app/api/orders/route.ts and lib/uploads.ts).
const int maxLineQuantity = 100;
const int maxCartLines = 50;
const int maxImageBytes = 5 * 1024 * 1024;
const int maxAvatarBytes = 1536 * 1024;

/// Stock level at or below which a part is shown as "limited quantity" (LOW_STOCK_THRESHOLD in lib/status.ts).
const int lowStockThreshold = 5;

/// Days a workshop has to repay debt, counted from its last debit entry.
const int debtWindowDays = 30;

const String otherLabel = 'أخرى';

/// Car brands accepted by POST /api/special-requests (BRANDS in lib/data.ts). Order matters for display.
const List<String> carBrands = <String>[
  'Mercedes-Benz',
  'BMW',
  'Audi',
  'Range Rover',
  'Volkswagen',
];

/// Brands a workshop can pick as its specialty when registering (AVAILABLE_BRANDS in app/login/page.tsx).
const List<String> specialtyBrands = <String>[
  'Mercedes-Benz',
  'BMW',
  'Audi',
  'Volkswagen',
  'Range Rover',
  'Porsche',
  otherLabel,
];

/// Syrian governorates (same list as the web registration and account pages).
const List<String> governorates = <String>[
  'دمشق',
  'ريف دمشق',
  'حلب',
  'حمص',
  'حماة',
  'اللاذقية',
  'طرطوس',
  'إدلب',
  'دير الزور',
  'الرقة',
  'الحسكة',
  'درعا',
  'السويداء',
  'القنيطرة',
];

/// Governorate preselected on the registration form (same default as the web).
const String defaultGovernorate = 'حلب';

/// Company details shown on the About page (address and contact).
const String companyAddressAr = 'إدلب، سرمدا';
const String companyAddressEn = 'Idlib, Sarmada';
const String companyNameAr = 'شركة اليورو';
const String companyWebsite = 'https://al-euro-cdzo.onrender.com';

/// Social pages shown as the two icons of the About page.
const String instagramUrl = 'https://www.instagram.com/36ue/';
const String tiktokUrl = 'https://www.tiktok.com/@9b2q6?_r=1&_t=ZS-9AwFs016GP6';

/// Sham Cash receiving account (shown in the cart so the customer can pay before attaching the receipt).
const String shamCashAccountName = 'شركة اليورو';
const String shamCashAccountAddress = 'a0033150665cd147ba987857dc01c61c';
const String shamCashQrAsset = 'assets/images/sham_cash_qr.png';

/// Days an account stays recoverable after the user asks to delete it (the server enforces the same 30 days).
const int accountDeletionGraceDays = 30;
