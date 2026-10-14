import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:serlink/design_system/design_system.dart';

void main() {
  testWidgets('mask follows both edges and clears after viewport resize', (
    tester,
  ) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    Future<void> render(double height) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: RepaintBoundary(
              key: const ValueKey('capture'),
              child: ColoredBox(
                color: Colors.white,
                child: SizedBox(
                  width: 100,
                  height: height,
                  child: SerlinkScrollView(
                    controller: controller,
                    child: const ColoredBox(
                      color: Color(0xffff0000),
                      child: SizedBox(height: 400),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    await render(100);
    expect(await _greenAt(tester, 50, 1), 0);
    expect(await _greenAt(tester, 50, 98), greaterThan(200));

    controller.jumpTo(100);
    await tester.pumpAndSettle();
    expect(await _greenAt(tester, 50, 1), greaterThan(200));
    expect(await _greenAt(tester, 50, 98), greaterThan(200));

    controller.jumpTo(controller.position.maxScrollExtent);
    await tester.pumpAndSettle();
    expect(await _greenAt(tester, 50, 1), greaterThan(200));
    expect(await _greenAt(tester, 50, 98), 0);

    await render(450);
    expect(await _greenAt(tester, 50, 1), 0);
    expect(await _greenAt(tester, 50, 398), 0);
    expect(controller.offset, 0);
  });

  testWidgets('nested horizontal scrolling keeps the vertical mask unchanged', (
    tester,
  ) async {
    final outer = ScrollController();
    final inner = ScrollController();
    addTearDown(outer.dispose);
    addTearDown(inner.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: RepaintBoundary(
            key: const ValueKey('capture'),
            child: ColoredBox(
              color: Colors.white,
              child: SizedBox(
                width: 100,
                height: 100,
                child: SerlinkScrollView(
                  controller: outer,
                  child: Column(
                    children: [
                      SerlinkScrollView(
                        controller: inner,
                        scrollDirection: Axis.horizontal,
                        child: const ColoredBox(
                          color: Color(0xffff0000),
                          child: SizedBox(width: 400, height: 100),
                        ),
                      ),
                      const SizedBox(height: 300),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    inner.jumpTo(100);
    await tester.pumpAndSettle();
    expect(outer.offset, 0);
    expect(await _greenAt(tester, 50, 1), 0);
    expect(await _greenAt(tester, 50, 98), greaterThan(200));
    expect(await _greenAt(tester, 1, 50), greaterThan(200));
    expect(await _greenAt(tester, 98, 50), greaterThan(200));
  });

  testWidgets('reversed horizontal viewport fades the physical hidden edge', (
    tester,
  ) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: RepaintBoundary(
            key: const ValueKey('capture'),
            child: ColoredBox(
              color: Colors.white,
              child: SizedBox.square(
                dimension: 100,
                child: SerlinkScrollFade(
                  child: SingleChildScrollView(
                    controller: controller,
                    scrollDirection: Axis.horizontal,
                    reverse: true,
                    child: const ColoredBox(
                      color: Color(0xffff0000),
                      child: SizedBox(width: 400, height: 100),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(await _greenAt(tester, 1, 50), greaterThan(200));
    expect(await _greenAt(tester, 98, 50), 0);
  });
}

Future<int> _greenAt(WidgetTester tester, int x, int y) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const ValueKey('capture')),
  );
  return tester
      .runAsync(() async {
        final image = await boundary.toImage();
        final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
        final green = data!.getUint8((y * image.width + x) * 4 + 1);
        image.dispose();
        return green;
      })
      .then((value) => value!);
}
