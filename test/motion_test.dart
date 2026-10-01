import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ecora/gestore_events.dart';
import 'package:ecora/models.dart';
import 'package:ecora/motion.dart';

class _Counter extends StatefulWidget {
  const _Counter({Key? key}) : super(key: key);
  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  int n = 0;
  @override
  Widget build(BuildContext context) => TextButton(
        onPressed: () => setState(() => n++),
        child: Text('n=$n'),
      );
}

Widget _host(Widget child, {bool reduced = false}) => MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reduced),
        child: Scaffold(body: child),
      ),
    );

SupabaseEvent _ev(String id) => SupabaseEvent(
      id: id,
      title: 'Serata $id',
      description: '',
      organizerId: 'h',
      latitude: 0,
      longitude: 0,
      imageUrl: '',
      eventDate: '2026-10-10T21:00:00',
      maxParticipants: 10,
      currentApprovedCount: 4,
    );

double _fadeOpacity(WidgetTester tester) => tester
    .widget<FadeTransition>(find.descendant(
        of: find.byType(FadeIndexedStack),
        matching: find.byType(FadeTransition)))
    .opacity
    .value;

void main() {
  test('il tag Hero è unico per evento', () {
    expect(eventCoverHeroTag('a'), isNot(eventCoverHeroTag('b')));
    expect(eventCoverHeroTag('a'), eventCoverHeroTag('a'));
  });

  group('FadeIndexedStack', () {
    Widget stack(int index, {bool reduced = false}) => _host(
          FadeIndexedStack(
            index: index,
            children: const [_Counter(), Text('due')],
          ),
          reduced: reduced,
        );

    testWidgets('conserva lo stato dei tab e dissolve il nuovo',
        (tester) async {
      await tester.pumpWidget(stack(0));
      await tester.tap(find.text('n=0'));
      await tester.pump();
      expect(find.text('n=1'), findsOneWidget);

      await tester.pumpWidget(stack(1));
      expect(_fadeOpacity(tester), 0);
      await tester.pump(const Duration(milliseconds: 110));
      expect(_fadeOpacity(tester), inExclusiveRange(0, 1));
      await tester.pumpAndSettle();
      expect(_fadeOpacity(tester), 1);

      await tester.pumpWidget(stack(0));
      await tester.pumpAndSettle();
      expect(find.text('n=1'), findsOneWidget);
    });

    testWidgets('con rimuovi animazioni il cambio è immediato',
        (tester) async {
      await tester.pumpWidget(stack(0, reduced: true));
      await tester.pumpWidget(stack(1, reduced: true));
      expect(_fadeOpacity(tester), 1);
    });
  });

  group('EcoraHero', () {
    testWidgets('crea un Hero con il tag dato', (tester) async {
      await tester.pumpWidget(_host(
          EcoraHero(tag: eventCoverHeroTag('a'), child: const SizedBox())));
      expect(tester.widget<Hero>(find.byType(Hero)).tag, 'event-cover-a');
    });

    testWidgets('niente Hero se il movimento è ridotto', (tester) async {
      await tester.pumpWidget(_host(
          EcoraHero(tag: eventCoverHeroTag('a'), child: const SizedBox()),
          reduced: true));
      expect(find.byType(Hero), findsNothing);
    });
  });

  group('card delle serate', () {
    for (final reduced in [false, true]) {
      testWidgets(
          'NextEventCard: richieste e Valuta compaiono e spariscono '
          '(movimento ridotto: $reduced)', (tester) async {
        Widget card(int pending) => _host(
              NextEventCard(
                event: _ev('a'),
                pendingCount: pending,
                onTap: () {},
                onEvaluate: () {},
              ),
              reduced: reduced,
            );
        await tester.pumpWidget(card(2));
        expect(find.text('2 richieste da valutare'), findsOneWidget);
        expect(find.text('Valuta'), findsOneWidget);

        await tester.pumpWidget(card(0));
        await tester.pumpAndSettle();
        expect(find.textContaining('da valutare'), findsNothing);
        expect(find.text('Valuta'), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('UpcomingEventTile: il bordo del tassello segue le richieste',
        (tester) async {
      Widget tile(int pending) => _host(
            UpcomingEventTile(
                event: _ev('b'), pendingCount: pending, onTap: () {}),
            reduced: true,
          );
      Color border() {
        final box = tester
            .widget<AnimatedContainer>(find.byType(AnimatedContainer).first);
        return ((box.decoration as BoxDecoration).border as Border).top.color;
      }

      await tester.pumpWidget(tile(0));
      final idle = border();
      await tester.pumpWidget(tile(1));
      await tester.pumpAndSettle();
      expect(border(), isNot(idle));
    });
  });
}
