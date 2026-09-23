import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:serlink/platform/ios_native_tab_bar.dart';

void main() {
  const platform = MethodChannel('serlink/platform');
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  final messenger = binding.defaultBinaryMessenger;
  late List<MethodCall> updates;
  int? viewId;

  setUp(() {
    updates = [];
    viewId = null;
    messenger.setMockMethodCallHandler(SystemChannels.platform_views, (
      call,
    ) async {
      if (call.method == 'create') {
        viewId = (call.arguments as Map)['id'] as int;
        messenger.setMockMethodCallHandler(
          MethodChannel('serlink/native_tab_bar/$viewId'),
          (call) async {
            updates.add(call);
            return null;
          },
        );
      }
      return null;
    });
  });
  tearDown(() {
    messenger.setMockMethodCallHandler(platform, null);
    messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
    if (viewId != null) {
      messenger.setMockMethodCallHandler(
        MethodChannel('serlink/native_tab_bar/$viewId'),
        null,
      );
    }
  });

  Widget app({
    int index = 0,
    ValueChanged<int>? onChanged,
    bool translated = false,
  }) {
    return CupertinoApp(
      home: Align(
        alignment: Alignment.bottomCenter,
        child: IosNativeTabBar(
          index: index,
          labels: translated
              ? ['主机', '会话', '传输', '片段', '设置']
              : ['Hosts', 'Sessions', 'Transfers', 'Snippets', 'Settings'],
          onChanged: onChanged ?? (_) {},
          tint: CupertinoColors.activeBlue,
          brightness: Brightness.light,
          fallback: const Text('Cupertino fallback'),
        ),
      ),
    );
  }

  Future<void> nativeCall(String method, Object value) async {
    await messenger.handlePlatformMessage(
      'serlink/native_tab_bar/$viewId',
      const StandardMethodCodec().encodeMethodCall(MethodCall(method, value)),
      (_) {},
    );
  }

  for (final available in [false, null]) {
    testWidgets('preserves fallback when native support is $available', (
      tester,
    ) async {
      messenger.setMockMethodCallHandler(
        platform,
        available == null ? null : (_) async => available,
      );
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      expect(find.text('Cupertino fallback'), findsOneWidget);
      expect(find.byType(UiKitView), findsNothing);
    });
  }

  testWidgets(
    'synchronizes selection and translated labels without recreating the view',
    (tester) async {
      messenger.setMockMethodCallHandler(platform, (_) async => true);
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      expect(find.byType(UiKitView), findsOneWidget);
      final initialId = viewId;
      await tester.pumpWidget(app(index: 4, translated: true));
      await tester.pumpAndSettle();
      expect(viewId, initialId);
      expect(updates.last.arguments['index'], 4);
      expect(updates.last.arguments['labels'], ['主机', '会话', '传输', '片段', '设置']);
    },
  );

  testWidgets(
    'accepts native selection and measured height, rejects invalid callbacks',
    (tester) async {
      messenger.setMockMethodCallHandler(platform, (_) async => true);
      final selected = <int>[];
      await tester.pumpWidget(app(onChanged: selected.add));
      await tester.pumpAndSettle();
      await nativeCall('select', 3);
      await nativeCall('select', -1);
      await nativeCall('select', 5);
      await nativeCall('height', 96.0);
      await tester.pump();
      expect(selected, [3]);
      expect(tester.getSize(find.byType(UiKitView)).height, 96);
      await nativeCall('height', -20);
      await tester.pump();
      expect(tester.getSize(find.byType(UiKitView)).height, 96);
      await tester.pumpWidget(const SizedBox());
      await nativeCall('select', 2);
      expect(selected, [3]);
      expect(tester.takeException(), isNull);
    },
  );
}
