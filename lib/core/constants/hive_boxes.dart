class HiveBoxes {
  const HiveBoxes._();

  static const String session = 'session_box';
  static const String sessionKey = 'current_session';
  static const String offlineTpsSessionKey = 'offline_tps_session';

  static const String preferences = 'preferences_box';
  static const String localeKey = 'locale';
  static const String authOfflineModeEnabledKey = 'auth_offline_mode_enabled';
  static const String tpsOfflineDistributionsKey = 'tps_offline_distributions';
  static const String tpsOfflineFcasKey = 'tps_offline_fcas';
  static const String tpsOfflineDistributionDraftsKey =
      'tps_offline_distribution_drafts';
  static const String tpsOfflineFcaDraftsKey = 'tps_offline_fca_drafts';
  static const String tpsFcaProvinceOptionsCacheKey =
      'tps_fca_province_options_cache';
  static const String tpsFcaTractorOptionsCacheKey =
      'tps_fca_tractor_options_cache';
  static const String tpsTpsUserOptionsCacheKey = 'tps_tps_user_options_cache';
  static const String tpsFcaCitiesCachePrefix = 'tps_fca_cities_cache_';
  static const String tpsFcaBarangaysCachePrefix = 'tps_fca_barangays_cache_';
  static const String tpsOfflineDistributionsSyncedAtKey =
      'tps_offline_distributions_synced_at';
  static const String tpsOfflineFcasSyncedAtKey = 'tps_offline_fcas_synced_at';
  static const String tpsOfflineReferenceDataSyncedAtKey =
      'tps_offline_reference_data_synced_at';
  static const String fcaCreateDetailsDraftKey = 'fca_create_details_draft';
  static const String fcaCreateDraftKey = 'fca_create_draft';
}
