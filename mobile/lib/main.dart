import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import 'app.dart';
import 'core/analytics_route_observer.dart';
import 'core/api_client.dart';
import 'core/config.dart';
import 'core/connectivity.dart';
import 'core/device_context.dart';
import 'core/local_store.dart';
import 'services/account_repository.dart';
import 'services/ads_service.dart';
import 'services/analytics_service.dart';
import 'services/auth_repository.dart';
import 'services/consent_repository.dart';
import 'services/content_service.dart';
import 'services/crash_reporting.dart';
import 'services/game_repository.dart';
import 'services/iap_service.dart';
import 'services/kids_zone_repository.dart';
import 'services/leaderboard_repository.dart';
import 'services/notification_service.dart';
import 'services/oauth_provider_service.dart';
import 'services/version_repository.dart';
import 'services/text_to_speech_service.dart';
import 'state/bootstrap_controller.dart';
import 'state/session_controller.dart';
import 'state/settings_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Dark status-bar icons, because the app is parchment on every screen. Only
  // AppBarTheme was setting this, and the branded screens (splash, level map,
  // profile, leaderboard, practice) have no AppBar to set it — so on a phone in
  // night mode Android chose light icons and painted the clock white on cream.
  // Set here rather than per screen: the one place it cannot be forgotten.
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  // Error handlers are installed before the first frame, and a missing Firebase
  // config simply leaves crash reporting off (see CrashReporting).
  // A release build that was never pointed at a backend fails here rather than
  // installing and quietly failing every request (see AppConfig).
  AppConfig.assertReleaseConfig();

  await CrashReporting.runGuarded(() async {
    final LocalStore store = await LocalStore.open();
    final DeviceContext device = await DeviceContext.resolve(store);

    final ApiClient api = ApiClient(deviceContext: device);

    final ConnectivityService connectivity = ConnectivityService();
    await connectivity.start();

    final AnalyticsService analytics = AnalyticsService(
      api: api,
      store: store,
      connectivity: connectivity,
    );

    final OAuthProviderService oauth = OAuthProviderService(store);
    final AuthRepository auth = AuthRepository(api);
    final AccountRepository account = AccountRepository(api, store);
    final ConsentRepository consent = ConsentRepository(api);
    final GameRepository game = GameRepository(api, store);
    final LeaderboardRepository leaderboard = LeaderboardRepository(api, store);
    final KidsZoneRepository kidsZone = KidsZoneRepository(api, store);
    final VersionRepository version = VersionRepository(api, device, store);

    final ContentService content = ContentService(
      api: api,
      store: store,
      analytics: analytics,
    );
    final IapService iap = IapService(api: api, analytics: analytics);
    final AdsService ads = AdsService(api: api);
    final NotificationService notifications = NotificationService(
      store: store,
      analytics: analytics,
    );
    final TextToSpeechService tts = TextToSpeechService();

    final SessionController session = SessionController(
      api: api,
      auth: auth,
      account: account,
      store: store,
      analytics: analytics,
      oauth: oauth,
      kidsZone: kidsZone,
    );
    final SettingsController settings = SettingsController(store);
    final BootstrapController bootstrap = BootstrapController(
      session: session,
      version: version,
      content: content,
      connectivity: connectivity,
      analytics: analytics,
      store: store,
    );

    final AnalyticsRouteObserver routeObserver = AnalyticsRouteObserver(analytics);

    runApp(
      MultiProvider(
        providers: <SingleChildWidget>[
          Provider<LocalStore>.value(value: store),
          Provider<DeviceContext>.value(value: device),
          Provider<ApiClient>.value(value: api),
          Provider<AnalyticsService>.value(value: analytics),
          Provider<AnalyticsRouteObserver>.value(value: routeObserver),
          Provider<OAuthProviderService>.value(value: oauth),
          Provider<AuthRepository>.value(value: auth),
          Provider<AccountRepository>.value(value: account),
          Provider<ConsentRepository>.value(value: consent),
          Provider<GameRepository>.value(value: game),
          Provider<LeaderboardRepository>.value(value: leaderboard),
          Provider<KidsZoneRepository>.value(value: kidsZone),
          Provider<VersionRepository>.value(value: version),
          ChangeNotifierProvider<NotificationService>.value(value: notifications),
          ChangeNotifierProvider<TextToSpeechService>.value(value: tts),
          ChangeNotifierProvider<ConnectivityService>.value(value: connectivity),
          ChangeNotifierProvider<ContentService>.value(value: content),
          ChangeNotifierProvider<IapService>.value(value: iap),
          ChangeNotifierProvider<AdsService>.value(value: ads),
          ChangeNotifierProvider<SessionController>.value(value: session),
          ChangeNotifierProvider<SettingsController>.value(value: settings),
          ChangeNotifierProvider<BootstrapController>.value(value: bootstrap),
        ],
        child: const AnointedApp(),
      ),
    );
  });
}
