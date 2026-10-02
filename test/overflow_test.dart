import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:ecora/account_deletion.dart';
import 'package:ecora/client_navigation_hub.dart';
import 'package:ecora/event_details_page.dart';
import 'package:ecora/gestore_dashboard.dart';
import 'package:ecora/models.dart';
import 'package:ecora/theme.dart';
import 'package:ecora/user_profile_page.dart';

// Guardia contro gli overflow dopo il passaggio a testi minimi di 12px
// (Blocco D.2b): schermo stretto (360 px) e testo di sistema ingrandito.

SupabaseEvent _event({String title = 'Serata di apertura con titolo lungo'}) =>
    SupabaseEvent(
      id: 'e1',
      title: title,
      description: 'Una serata tranquilla in un locale del centro.',
      organizerId: 'h1',
      latitude: 43.77,
      longitude: 11.25,
      imageUrl: '',
      eventDate: DateTime.now().add(const Duration(days: 3)).toIso8601String(),
      maxParticipants: 20,
      currentApprovedCount: 12,
      locationName: 'Via dei Servi 12, Firenze',
    );

final _profile = SupabaseProfile(
  id: 'u1',
  fullName: 'Arcadia Club Bologna',
  role: 'cliente',
  gender: 'Coppia',
  birthYear: 1990,
  genericLocation: 'Bologna',
);

final _request = SupabaseParticipationRequest(
  id: 'r1',
  userId: 'u2',
  eventId: 'e1',
  status: 'pending',
  createdAt: DateTime.now(),
);

final _screens = <String, Widget Function()>{
  'EventFeedCard': () => EventFeedCard(event: _event(), onClick: () {}),
  'NotificationsScreen': () => NotificationsScreen(
        notifications: [
          NotificationItem(
            id: 'n1',
            eventId: 'e1',
            eventTitle: 'Serata di apertura con titolo lungo',
            status: 'approved',
            timestamp: '2026-10-01T20:00:00',
          ),
        ],
        onDeleteNotification: (_) {},
      ),
  'ChatRoomCard': () => ChatRoomCard(event: _event(), subtitle: 'Ospite'),
  'GestoreBottomNav': () => Align(
        alignment: Alignment.bottomCenter,
        child:
            GestoreBottomNav(currentIndex: 0, pendingCount: 12, onTap: (_) {}),
      ),
  'ClubDashboardScreen': () => ClubDashboardScreen(
        host: _profile,
        events: [_event(), _event(title: 'Seconda serata')],
        requests: [_request],
        onSelectRequestInspector: () {},
        onCreateEvent: () {},
      ),
  'RequestInspectorScreen': () => RequestInspectorScreen(
        events: [_event()],
        requests: [_request],
      ),
  'EventDetailsPage': () => EventDetailsPage(event: _event()),
  'UserProfilePage': () => UserProfilePage(profile: _profile, onLogout: () {}),
  'DeleteAccountSheet': () => DeleteAccountSheet(
        warnings: const DeletionWarnings(
          isGestore: true,
          upcomingEvents: 12,
          approvedGuests: 140,
          activeSubscription: true,
        ),
        onDelete: (_) async => null,
        onDeleted: () {},
        onOpenGooglePlay: () {},
      ),
  'StatMetricField': () => const StatMetricField(
        label: 'PRESENZE',
        value: '12',
        indicatorColor: EcoraColors.brass,
      ),
};

/// Nei widget test il testo usa il font Ahem (ogni carattere è un quadrato):
/// senza i font veri gli overflow in larghezza sono gonfiati.
Future<void> _loadFont(String family, List<String> files) async {
  final loader = FontLoader(family);
  for (final f in files) {
    final bytes = File('assets/fonts/$f').readAsBytesSync();
    loader.addFont(Future.value(ByteData.sublistView(bytes)));
  }
  await loader.load();
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/shared_preferences'),
      (call) async => call.method == 'getAll' ? <String, Object>{} : true,
    );
    // Client finto: nessuna sessione, nessuna rete (EventDetailsPage lo legge).
    await Supabase.initialize(
      url: 'http://localhost:1',
      anonKey: 'test',
      localStorage: const EmptyLocalStorage(),
    );
    await _loadFont('EcoraDisplay', ['BodoniModa-MediumItalic.ttf']);
    await _loadFont('EcoraUI', [
      'HankenGrotesk-Regular.ttf',
      'HankenGrotesk-Medium.ttf',
      'HankenGrotesk-SemiBold.ttf',
      'HankenGrotesk-Bold.ttf',
    ]);
  });

  for (final scale in [1.0, 1.3]) {
    for (final entry in _screens.entries) {
      testWidgets('${entry.key} senza overflow a 360px, testo x$scale',
          (tester) async {
        tester.view.physicalSize = const Size(360, 780);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        final overflows = <String>[];
        final previous = FlutterError.onError;
        FlutterError.onError = (details) {
          final text = details.toString();
          if (text.contains('overflowed')) {
            overflows.add(text.split('\n').first);
          }
        };

        await tester.pumpWidget(MaterialApp(
          theme: ecoraTheme(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(scale),
            ),
            child: child!,
          ),
          home: Scaffold(body: entry.value()),
        ));
        await tester.pump(const Duration(milliseconds: 500));

        FlutterError.onError = previous;
        expect(overflows, isEmpty);
      });
    }
  }
}
