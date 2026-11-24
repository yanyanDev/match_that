// Shared helpers for the Setup and Names screen widget tests (step 8c).

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:match_that/cubits/setup_cubit.dart';
import 'package:match_that/ui/app_theme.dart';

/// The text on the page under the screen being tested, so tests can see
/// when a screen popped.
const belowPage = 'PAGE BELOW';

/// Shows [page] on a phone-sized screen, pushed on top of a plain page, with
/// a [SetupCubit] provided *above* MaterialApp, where the app provides it
/// (D14), so every pushed route can find it.
///
/// Returns the Cubit, to check what a tap did. The test made it, so the test
/// closes it.
Future<SetupCubit> pumpWithSetup(
  WidgetTester tester,
  Widget page, {
  SetupCubit? cubit,
}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.625;
  addTearDown(tester.view.reset);

  final setup = cubit ?? SetupCubit();
  addTearDown(setup.close);

  final navigator = GlobalKey<NavigatorState>();
  await tester.pumpWidget(
    BlocProvider.value(
      value: setup,
      child: MaterialApp(
        navigatorKey: navigator,
        theme: buildAppTheme(),
        home: const Scaffold(body: Center(child: Text(belowPage))),
      ),
    ),
  );
  navigator.currentState!.push(MaterialPageRoute<void>(builder: (_) => page));
  await tester.pumpAndSettle(); // finish the page transition
  return setup;
}
