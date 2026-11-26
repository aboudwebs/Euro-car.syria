// Reads a marketer's invitation: either a plain code (MK-1A2B3C) or the signed link the marketer dashboard
// produces (https://.../login?ref=MK-1A2B3C&sig=...). A link carries a signature that the server checks, so the
// code from a link must not be edited.

const int _maxReferralLength = 80;

class ReferralInput {
  const ReferralInput({this.code = '', this.signature = ''});

  final String code;
  final String signature;

  bool get isEmpty => code.isEmpty;

  /// True when the code came from a signed link.
  bool get isSigned => code.isNotEmpty && signature.isNotEmpty;
}

ReferralInput parseReferral(String raw) {
  final String text = raw.trim();
  if (text.isEmpty) {
    return const ReferralInput();
  }

  final int questionMark = text.indexOf('?');
  String query = '';
  if (questionMark >= 0) {
    query = text.substring(questionMark + 1);
  } else if (text.contains('ref=')) {
    query = text;
  }
  final int hash = query.indexOf('#');
  if (hash >= 0) {
    query = query.substring(0, hash);
  }

  if (query.isNotEmpty) {
    try {
      final Map<String, String> params = Uri.splitQueryString(query);
      final String code = _limit((params['ref'] ?? '').trim());
      final String signature = (params['sig'] ?? '').trim();
      if (code.isNotEmpty) {
        return ReferralInput(code: code, signature: signature);
      }
    } on FormatException {
      // Not a readable query string (for example bytes that are not UTF-8): treat the text as a plain code.
    } on ArgumentError {
      // Uri.splitQueryString reports a broken percent sequence ("%ZZ", a trailing "%") or a non-ASCII character
      // with an ArgumentError, so pasted junk must not escape as an exception either.
    }
  }
  return ReferralInput(code: _limit(text));
}

String _limit(String value) {
  return value.length > _maxReferralLength ? value.substring(0, _maxReferralLength) : value;
}
