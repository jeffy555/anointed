/// `GET /v1/version/minimum` — the force-upgrade gate (design-spec §16).
///
/// The server decides [forceUpgradeRequired] from the version the client sends,
/// so the client never compares semver itself.
class MinimumVersion {
  const MinimumVersion({
    required this.minimumVersion,
    required this.currentStoreVersion,
    required this.minimumAppBuild,
    required this.forceUpgradeRequired,
    required this.releaseNotes,
    required this.appStoreUrl,
    required this.playStoreUrl,
  });

  factory MinimumVersion.fromJson(Map<String, dynamic> json) => MinimumVersion(
        minimumVersion: '${json['minimum_version'] ?? ''}',
        currentStoreVersion: '${json['current_store_version'] ?? ''}',
        minimumAppBuild: (json['minimum_app_build'] as num?)?.toInt() ?? 1,
        forceUpgradeRequired: json['force_upgrade_required'] == true,
        releaseNotes: json['release_notes'] as String?,
        appStoreUrl: '${json['app_store_url'] ?? ''}',
        playStoreUrl: '${json['play_store_url'] ?? ''}',
      );

  final String minimumVersion;
  final String currentStoreVersion;
  final int minimumAppBuild;
  final bool forceUpgradeRequired;
  final String? releaseNotes;
  final String appStoreUrl;
  final String playStoreUrl;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'minimum_version': minimumVersion,
        'current_store_version': currentStoreVersion,
        'minimum_app_build': minimumAppBuild,
        'force_upgrade_required': forceUpgradeRequired,
        'release_notes': releaseNotes,
        'app_store_url': appStoreUrl,
        'play_store_url': playStoreUrl,
      };
}
