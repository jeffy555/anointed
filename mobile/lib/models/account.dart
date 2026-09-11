import 'session.dart';

/// `GET /v1/account/profile` — M-26.
class UserProfile {
  const UserProfile({
    required this.id,
    required this.name,
    required this.ageGroup,
    required this.isUnder13,
    required this.accountStatus,
    required this.authProvider,
    required this.levelsCompleted,
    required this.highestLevelCompleted,
    required this.totalScore,
    required this.hasUnlock,
    required this.purchaseDisplayPrice,
    required this.notificationsOptIn,
    required this.memberSince,
    required this.privacyPolicyUrl,
    required this.termsOfServiceUrl,
    required this.supportEmail,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        id: '${json['id']}',
        name: json['name'] as String?,
        ageGroup: AgeGroup.parse(json['age_group']),
        isUnder13: json['is_under_13'] == true,
        accountStatus: AccountStatus.parse(json['account_status']),
        authProvider: json['auth_provider'] as String?,
        levelsCompleted: (json['levels_completed'] as num?)?.toInt() ?? 0,
        highestLevelCompleted: (json['highest_level_completed'] as num?)?.toInt() ?? 0,
        totalScore: (json['total_score'] as num?)?.toInt() ?? 0,
        hasUnlock: json['has_unlock'] == true,
        purchaseDisplayPrice: json['purchase_display_price'] as String?,
        notificationsOptIn: json['notifications_opt_in'] == true,
        memberSince: DateTime.tryParse('${json['member_since']}'),
        privacyPolicyUrl: '${json['privacy_policy_url'] ?? ''}',
        termsOfServiceUrl: '${json['terms_of_service_url'] ?? ''}',
        supportEmail: '${json['support_email'] ?? ''}',
      );

  final String id;
  final String? name;
  final AgeGroup? ageGroup;
  final bool isUnder13;
  final AccountStatus accountStatus;
  final String? authProvider;
  final int levelsCompleted;
  final int highestLevelCompleted;
  final int totalScore;
  final bool hasUnlock;
  final String? purchaseDisplayPrice;
  final bool notificationsOptIn;
  final DateTime? memberSince;
  final String privacyPolicyUrl;
  final String termsOfServiceUrl;
  final String supportEmail;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'age_group': ageGroup?.wireValue,
        'is_under_13': isUnder13,
        'account_status': accountStatus.wireValue,
        'auth_provider': authProvider,
        'levels_completed': levelsCompleted,
        'highest_level_completed': highestLevelCompleted,
        'total_score': totalScore,
        'has_unlock': hasUnlock,
        'purchase_display_price': purchaseDisplayPrice,
        'notifications_opt_in': notificationsOptIn,
        'member_since': memberSince?.toIso8601String(),
        'privacy_policy_url': privacyPolicyUrl,
        'terms_of_service_url': termsOfServiceUrl,
        'support_email': supportEmail,
      };
}

/// `GET /v1/account/deletion-preview` — the M-29a/M-29b disclosure.
class DeletionPreview {
  const DeletionPreview({
    required this.levelsCompleted,
    required this.hasUnlock,
    required this.isUnder13,
    required this.removed,
    required this.retainedAnonymized,
    required this.warning,
  });

  factory DeletionPreview.fromJson(Map<String, dynamic> json) => DeletionPreview(
        levelsCompleted: (json['levels_completed'] as num?)?.toInt() ?? 0,
        hasUnlock: json['has_unlock'] == true,
        isUnder13: json['is_under_13'] == true,
        removed: _strings(json['removed']),
        retainedAnonymized: _strings(json['retained_anonymized']),
        warning: '${json['warning'] ?? ''}',
      );

  final int levelsCompleted;
  final bool hasUnlock;
  final bool isUnder13;

  /// Server-authored disclosure copy. Kept as server strings rather than ARB keys
  /// because the retention wording is a legal statement that must be correctable
  /// without an app release — noted as an assumption in mobile/README.md.
  final List<String> removed;
  final List<String> retainedAnonymized;
  final String warning;

  static List<String> _strings(Object? raw) {
    if (raw is! List) return const <String>[];
    return raw.map((Object? item) => '$item').toList();
  }
}

class DeletionResult {
  const DeletionResult({
    required this.deleted,
    required this.levelsCompleted,
    required this.hadPurchase,
    required this.accountAgeDays,
    required this.message,
  });

  factory DeletionResult.fromJson(Map<String, dynamic> json) => DeletionResult(
        deleted: json['deleted'] == true,
        levelsCompleted: (json['levels_completed'] as num?)?.toInt() ?? 0,
        hadPurchase: json['had_purchase'] == true,
        accountAgeDays: (json['account_age_days'] as num?)?.toInt() ?? 0,
        message: '${json['message'] ?? ''}',
      );

  final bool deleted;
  final int levelsCompleted;
  final bool hadPurchase;
  final int accountAgeDays;
  final String message;
}

/// `GET /v1/account/faq` — M-31. Server-hosted so the account-recovery answer can
/// be corrected without an app store release (backend resolves OQ-07 this way).
class FaqItem {
  const FaqItem({
    required this.id,
    required this.category,
    required this.question,
    required this.answer,
  });

  factory FaqItem.fromJson(Map<String, dynamic> json) => FaqItem(
        id: '${json['id']}',
        category: '${json['category'] ?? ''}',
        question: '${json['question'] ?? ''}',
        answer: '${json['answer'] ?? ''}',
      );

  final String id;
  final String category;
  final String question;
  final String answer;
}

class FaqBundle {
  const FaqBundle({
    required this.items,
    required this.supportEmail,
  });

  factory FaqBundle.fromJson(Map<String, dynamic> json) => FaqBundle(
        items: ((json['items'] as List<dynamic>? ?? const <dynamic>[]))
            .map((Object? item) => FaqItem.fromJson(item as Map<String, dynamic>))
            .toList(),
        supportEmail: '${json['support_email'] ?? ''}',
      );

  final List<FaqItem> items;
  final String supportEmail;

  /// FAQ grouped by the categories design-spec §14 lists for the accordion.
  Map<String, List<FaqItem>> get byCategory {
    final Map<String, List<FaqItem>> grouped = <String, List<FaqItem>>{};
    for (final FaqItem item in items) {
      grouped.putIfAbsent(item.category, () => <FaqItem>[]).add(item);
    }
    return grouped;
  }
}
