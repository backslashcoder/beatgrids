import 'package:beatgrid/app/app.dart';
import 'package:beatgrid/app/router/app_router.dart';
import 'package:beatgrid/core/widgets/bg_button.dart';
import 'package:beatgrid/core/widgets/chips_and_toggles.dart';
import 'package:beatgrid/core/widgets/states.dart';
import 'package:beatgrid/app/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> pumpApp(WidgetTester tester, {String location = '/', Size size = const Size(1280, 900)}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(BeatGridApp(router: AppRouter.create(initialLocation: location)));
  await settle(tester);
}

/// The home hero loops forever, so pumpAndSettle would never finish.
Future<void> settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  testWidgets('desktop shows top navigation and no bottom bar', (tester) async {
    await pumpApp(tester);
    expect(find.text('Open the studio'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.text('Explore'), findsWidgets);
    expect(find.text('Sign up'), findsOneWidget);
  });

  testWidgets('mobile shows bottom navigation and no overflow', (tester) async {
    await pumpApp(tester, size: const Size(375, 812));
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Sign up'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('navigation moves between routes', (tester) async {
    await pumpApp(tester, size: const Size(375, 812));
    await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('Explore')));
    await settle(tester);
    expect(find.textContaining('trending beats'), findsOneWidget);
  });

  testWidgets('protected route redirects anonymous users to login', (tester) async {
    await pumpApp(tester, location: '/settings');
    expect(find.text('Sign in'), findsWidgets);
    expect(find.textContaining('Accounts are not connected'), findsOneWidget);
  });

  testWidgets('unknown route shows not-found state', (tester) async {
    await pumpApp(tester, location: '/nope');
    expect(find.text('Page not found'), findsOneWidget);
  });

  testWidgets('beat and profile routes accept parameters', (tester) async {
    await pumpApp(tester, location: '/profile/ada');
    expect(find.text('@ada'), findsWidgets);
  });

  testWidgets('studio route loads on desktop and mobile without overflow', (tester) async {
    await pumpApp(tester, location: '/studio');
    expect(find.text('Start audio engine'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await pumpApp(tester, location: '/studio', size: const Size(375, 812));
    expect(tester.takeException(), isNull);
  });

  testWidgets('BgButton while loading ignores taps', (tester) async {
    var taps = 0;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.dark,
      home: Scaffold(body: BgButton(label: 'Publish', loading: true, onPressed: () => taps++)),
    ));
    await tester.tap(find.text('Publish'));
    expect(taps, 0);
  });

  testWidgets('ErrorState retry fires', (tester) async {
    var retried = 0;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.dark,
      home: Scaffold(body: ErrorState(message: 'offline', onRetry: () => retried++)),
    ));
    await tester.tap(find.text('Try again'));
    expect(retried, 1);
  });

  testWidgets('BounceToggle reports taps and shows count', (tester) async {
    var taps = 0;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.dark,
      home: Scaffold(
        body: BounceToggle(
          active: false,
          icon: Icons.favorite_border,
          activeIcon: Icons.favorite,
          tooltip: 'Like',
          count: 7,
          onPressed: () => taps++,
        ),
      ),
    ));
    expect(find.text('7'), findsOneWidget);
    await tester.tap(find.byType(BounceToggle));
    expect(taps, 1);
  });
}
