import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ecora/account_deletion.dart';
import 'package:ecora/models.dart';
import 'package:ecora/subscription_service.dart';

final _now = DateTime(2026, 10, 2, 12);

SupabaseProfile _profile(String role) => SupabaseProfile(
      id: 'me',
      fullName: 'Io',
      role: role,
      gender: 'coppia',
    );

SupabaseEvent _event(String host, DateTime? date, int approved) =>
    SupabaseEvent(
      id: '$host-${date?.toIso8601String()}',
      title: 'Serata',
      description: '',
      organizerId: host,
      latitude: 0,
      longitude: 0,
      imageUrl: '',
      eventDate: date?.toIso8601String() ?? 'data illeggibile',
      maxParticipants: 20,
      currentApprovedCount: approved,
    );

SubscriptionStatus _subscription(DateTime expiry) => SubscriptionStatus(
      productId: kSubscriptionProductId,
      expiryTime: expiry,
      autoRenewing: true,
      lastVerifiedAt: null,
    );

/// Apre il foglio come fa il profilo; registra le chiamate.
class _Harness {
  final passwords = <String>[];
  int deleted = 0;
  int openedPlay = 0;
  Completer<String?> result = Completer<String?>();

  Future<void> open(WidgetTester tester,
      {DeletionWarnings warnings = const DeletionWarnings()}) async {
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              enableDrag: false,
              builder: (_) => DeleteAccountSheet(
                warnings: warnings,
                onDelete: (password) {
                  passwords.add(password);
                  return result.future;
                },
                onDeleted: () => deleted++,
                onOpenGooglePlay: () => openedPlay++,
              ),
            ),
            child: const Text('apri'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('apri'));
    await tester.pumpAndSettle();
  }

  Future<void> fill(WidgetTester tester,
      {String password = 'segreta', bool acknowledge = true}) async {
    await tester.enterText(find.byType(TextField), password);
    if (acknowledge) await tester.tap(find.text(kDeleteAccountAcknowledge));
    await tester.pump();
  }
}

Finder get _confirm =>
    find.widgetWithText(ElevatedButton, kDeleteAccountConfirm);
Finder get _confirmButton => find.byType(ElevatedButton);

bool _enabled(WidgetTester tester, Finder button) =>
    tester.widget<ButtonStyleButton>(button).onPressed != null;

void main() {
  group('DeletionWarnings.compute', () {
    test('cliente: nessun avviso in più', () {
      final w = DeletionWarnings.compute(
        profile: _profile('cliente'),
        events: [_event('me', _now.add(const Duration(days: 2)), 4)],
        subscription: _subscription(_now.add(const Duration(days: 9))),
        now: _now,
      );
      expect(w.isGestore, isFalse);
      expect(w.upcomingEvents, 0);
      expect(w.activeSubscription, isFalse);
    });

    test('gestore: conta solo le sue serate future e i loro ospiti', () {
      final w = DeletionWarnings.compute(
        profile: _profile('gestore'),
        events: [
          _event('me', _now.add(const Duration(days: 2)), 4),
          _event('me', _now.add(const Duration(days: 9)), 1),
          _event('me', null, 2), // data illeggibile: conta come futura
          _event('me', _now.subtract(const Duration(days: 1)), 7), // passata
          _event('altro', _now.add(const Duration(days: 2)), 9), // altro locale
        ],
        subscription: null,
        now: _now,
      );
      expect(w.isGestore, isTrue);
      expect(w.upcomingEvents, 3);
      expect(w.approvedGuests, 7);
      expect(w.activeSubscription, isFalse);
    });

    test('gestore: abbonamento attivo solo se non scaduto', () {
      DeletionWarnings at(DateTime expiry) => DeletionWarnings.compute(
            profile: _profile('gestore'),
            events: const [],
            subscription: _subscription(expiry),
            now: _now,
          );
      expect(at(_now.add(const Duration(days: 1))).activeSubscription, isTrue);
      expect(at(_now.subtract(const Duration(days: 1))).activeSubscription,
          isFalse);
    });
  });

  test('upcomingEventsWarning: singolare, plurale e senza ospiti', () {
    expect(upcomingEventsWarning(0, 3), '');
    expect(upcomingEventsWarning(1, 1),
        'La tua serata in programma (1 ospite approvato) verrà cancellata.');
    expect(upcomingEventsWarning(3, 5),
        'Le tue 3 serate in programma (5 ospiti approvati) verranno cancellate.');
    expect(upcomingEventsWarning(2, 0),
        'Le tue 2 serate in programma verranno cancellate.');
  });

  test('canConfirmDeletion: servono password e casella', () {
    expect(canConfirmDeletion(password: '', acknowledged: true), isFalse);
    expect(canConfirmDeletion(password: 'x', acknowledged: false), isFalse);
    expect(canConfirmDeletion(password: 'x', acknowledged: true), isTrue);
  });

  test('deletionErrorMessage: dalla risposta della funzione al messaggio', () {
    expect(deletionErrorMessage(200, {'ok': true}), isNull);
    expect(deletionErrorMessage(401, {'error': 'wrong_password'}),
        kDeleteAccountWrongPassword);
    expect(deletionErrorMessage(429, {'error': 'rate_limited'}),
        kDeleteAccountRateLimited);
    expect(deletionErrorMessage(401, {'error': 'unauthorized'}),
        kDeleteAccountFailed);
    expect(deletionErrorMessage(500, {'error': 'auth'}), kDeleteAccountFailed);
    expect(deletionErrorMessage(null, null), kDeleteAccountFailed);
  });

  test('il link a Google Play porta all\'abbonamento di Ecora', () {
    expect(kPlaySubscriptionsUrl,
        contains('sku=$kSubscriptionProductId&package=com.ecora.app'));
  });

  group('DeleteAccountSheet', () {
    testWidgets('pulsante spento finché mancano password o casella',
        (tester) async {
      final h = _Harness();
      await h.open(tester);
      expect(_enabled(tester, _confirmButton), isFalse);

      await h.fill(tester, acknowledge: false);
      expect(_enabled(tester, _confirmButton), isFalse);

      await h.fill(tester, password: '');
      expect(_enabled(tester, _confirmButton), isFalse);

      await h.fill(tester, acknowledge: false);
      expect(_enabled(tester, _confirm), isTrue);
    });

    testWidgets('Annulla chiude senza chiamare il server', (tester) async {
      final h = _Harness();
      await h.open(tester);
      await tester.tap(find.text(kDeleteAccountCancel));
      await tester.pumpAndSettle();
      expect(find.text(kDeleteAccountTitle), findsNothing);
      expect(h.passwords, isEmpty);
      expect(h.deleted, 0);
    });

    testWidgets('durante l\'attesa il foglio resta aperto e bloccato',
        (tester) async {
      final h = _Harness();
      await h.open(tester);
      await h.fill(tester);
      await tester.tap(_confirm);
      await tester.pump();

      expect(h.passwords, ['segreta']);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(_enabled(tester, _confirmButton), isFalse);
      expect(
          tester
              .widget<TextButton>(
                  find.widgetWithText(TextButton, kDeleteAccountCancel))
              .onPressed,
          isNull);

      // Né il tocco fuori né "indietro" lo chiudono mentre aspetta.
      await tester.tapAt(const Offset(4, 4));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text(kDeleteAccountTitle), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pump(const Duration(seconds: 1));
      expect(find.text(kDeleteAccountTitle), findsOneWidget);
    });

    testWidgets('con un errore il messaggio resta nel foglio e non si esce',
        (tester) async {
      final h = _Harness();
      await h.open(tester);
      await h.fill(tester);
      await tester.tap(_confirm);
      await tester.pump();
      h.result.complete(kDeleteAccountWrongPassword);
      await tester.pumpAndSettle();

      expect(find.text(kDeleteAccountTitle), findsOneWidget);
      expect(find.text(kDeleteAccountWrongPassword), findsOneWidget);
      expect(h.deleted, 0);
      expect(_enabled(tester, _confirm), isTrue);
    });

    testWidgets('a eliminazione riuscita si chiude e poi esce', (tester) async {
      final h = _Harness();
      await h.open(tester);
      await h.fill(tester);
      await tester.tap(_confirm);
      await tester.pump();
      expect(h.deleted, 0);
      h.result.complete(null);
      await tester.pumpAndSettle();

      expect(find.text(kDeleteAccountTitle), findsNothing);
      expect(h.deleted, 1);
    });

    testWidgets('cliente: niente avvisi su serate e abbonamento',
        (tester) async {
      final h = _Harness();
      await h.open(tester);
      expect(find.text(kDeleteAccountBody), findsOneWidget);
      expect(find.text(kDeleteAccountPastEvents), findsNothing);
      expect(find.text(kDeleteAccountSubscription), findsNothing);
      expect(find.text(kOpenGooglePlay), findsNothing);
    });

    testWidgets('gestore con serate e abbonamento: avvisi e link a Play',
        (tester) async {
      final h = _Harness();
      await h.open(tester,
          warnings: const DeletionWarnings(
            isGestore: true,
            upcomingEvents: 2,
            approvedGuests: 5,
            activeSubscription: true,
          ));
      expect(find.text(upcomingEventsWarning(2, 5)), findsOneWidget);
      expect(find.text(kDeleteAccountPastEvents), findsOneWidget);
      expect(find.text(kDeleteAccountSubscription), findsOneWidget);

      await tester.tap(find.text(kOpenGooglePlay));
      await tester.pump();
      expect(h.openedPlay, 1);
      expect(h.passwords, isEmpty);
    });
  });
}
