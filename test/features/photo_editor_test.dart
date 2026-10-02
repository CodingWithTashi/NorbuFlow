import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:norbu_flow/app/router/app_router.dart';
import 'package:norbu_flow/app/router/app_routes.dart';
import 'package:norbu_flow/core/services/photo_picker.dart';
import 'package:norbu_flow/core/widgets/buttons.dart';
import 'package:norbu_flow/features/members/domain/card.dart';
import 'package:norbu_flow/features/members/presentation/view_models/card_form_view_model.dart';
import 'package:norbu_flow/features/members/presentation/widgets/photo_cropper.dart';
import 'package:norbu_flow/features/settings/domain/app_preferences.dart';
import 'package:norbu_flow/features/settings/presentation/view_models/preferences_view_model.dart';

import '../support/cards.dart';
import '../support/test_app.dart';

const _red = Color(0xFFCC3333);
const _blue = Color(0xFF3366CC);
const _degree = math.pi / 180;

void main() {
  /// A controller with a photo loaded, and what [edit] left framed, as the
  /// pixels that would go on the card.
  Future<_Pixels> framed(
    WidgetTester tester, {
    required Uint8List photo,
    PhotoCropShape shape = const PhotoCropShape.idCard(),
    void Function(PhotoCropController controller)? edit,
  }) async {
    final controller = PhotoCropController(shape: shape);
    addTearDown(controller.dispose);
    return (await tester.runAsync(() async {
      await controller.load(photo);
      edit?.call(controller);
      return _Pixels.of(await controller.export(size: CardPhoto.longSide));
    }))!;
  }

  /// A controller for the round frame with a plain 600 by 800 photo loaded.
  Future<PhotoCropController> loaded(WidgetTester tester) async {
    final photo = (await tester.runAsync(() => _plain(600, 800)))!;
    final controller = PhotoCropController();
    addTearDown(controller.dispose);
    await tester.runAsync(() => controller.load(photo));
    return controller;
  }

  group('the photo editor', () {
    testWidgets('keeps the photo as it was taken until something is '
        'changed', (tester) async {
      // Red on the left, blue on the right.
      final photo = (await tester.runAsync(() => _split(1200, 900)))!;

      final kept = await framed(tester, photo: photo);

      expect(kept.size, const Size(662, 754));
      expect(kept.at(0.1, 0.5), _red);
      expect(kept.at(0.9, 0.5), _blue);
    });

    testWidgets('flips a mirrored selfie back, left to right', (tester) async {
      final photo = (await tester.runAsync(() => _split(1200, 900)))!;

      final kept = await framed(
        tester,
        photo: photo,
        edit: (controller) => controller.flip(),
      );

      expect(kept.at(0.1, 0.5), _blue);
      expect(kept.at(0.9, 0.5), _red);
    });

    testWidgets('flips what is framed, so a photo that was straightened, '
        'zoomed and moved comes out as its mirror image', (tester) async {
      final photo = (await tester.runAsync(() => _split(1200, 900)))!;
      void arrange(PhotoCropController controller) {
        controller
          ..setTilt(30 * _degree)
          ..setZoom(1.5);
        _drag(controller, const Offset(18, -9));
      }

      final before = await framed(tester, photo: photo, edit: arrange);
      final after = await framed(
        tester,
        photo: photo,
        edit: (controller) {
          arrange(controller);
          controller.flip();
          expect(controller.rotation, closeTo(-30 * _degree, 1e-9));
          expect(controller.zoom, closeTo(1.5, 1e-9));
        },
      );

      final points = [
        for (var x = 0.05; x < 1; x += 0.1)
          for (var y = 0.05; y < 1; y += 0.1) (x, y),
      ];
      // The slanted line between the colours makes the two sides differ.
      final lopsided = points.where(
        (point) =>
            before.at(point.$1, point.$2) != before.at(1 - point.$1, point.$2),
      );
      expect(lopsided.length, greaterThan(20));
      // A pixel on the line itself may round either way.
      final mirrored = points.where(
        (point) =>
            after.at(point.$1, point.$2) == before.at(1 - point.$1, point.$2),
      );
      expect(mirrored.length, greaterThanOrEqualTo(points.length - 4));
    });

    testWidgets('flipping twice puts the photo back exactly', (tester) async {
      final photo = (await tester.runAsync(() => _plain(600, 800)))!;
      final controller = PhotoCropController();
      addTearDown(controller.dispose);
      await tester.runAsync(() => controller.load(photo));
      controller
        ..setTilt(17 * _degree)
        ..setZoom(2);
      _drag(controller, const Offset(12, 7));
      final pan = controller.offset;

      controller
        ..flip()
        ..flip();

      expect(controller.flipped, isFalse);
      expect(controller.rotation, closeTo(17 * _degree, 1e-9));
      expect((controller.offset - pan).distance, lessThan(1e-9));
    });

    testWidgets('turns a quarter at a time: the top of the photo goes to '
        'the right', (tester) async {
      // Red above, blue below.
      final photo = (await tester.runAsync(
        () => _split(900, 1200, topAndBottom: true),
      ))!;

      final right = await framed(
        tester,
        photo: photo,
        edit: (controller) => controller.turnBy(1),
      );
      expect(right.at(0.9, 0.5), _red);
      expect(right.at(0.1, 0.5), _blue);

      final left = await framed(
        tester,
        photo: photo,
        edit: (controller) => controller.turnBy(-1),
      );
      expect(left.at(0.1, 0.5), _red);
      expect(left.at(0.9, 0.5), _blue);
    });

    for (final degrees in [7, 30, 45, 63, 117, -150, 180]) {
      testWidgets('turns freely to $degrees° and still fills the frame to '
          'every corner', (tester) async {
        final photo = (await tester.runAsync(() => _plain(1200, 900)))!;

        final kept = await framed(
          tester,
          photo: photo,
          edit: (controller) {
            _turnTo(controller, degrees);
            // Pushed as far as it will go, the frame must still be covered.
            _drag(controller, const Offset(4000, -4000));
          },
        );

        expect(kept.size, const Size(662, 754));
        for (final (x, y) in [
          (0.0, 0.0),
          (1.0, 0.0),
          (0.0, 1.0),
          (1.0, 1.0),
          (0.5, 0.5),
        ]) {
          expect(kept.at(x, y), _blue, reason: 'at $x, $y');
        }
      });
    }

    testWidgets('fills the round frame of the in-app card too', (tester) async {
      final photo = (await tester.runAsync(() => _plain(900, 1200)))!;

      final kept = await framed(
        tester,
        photo: photo,
        shape: const PhotoCropShape.circle(),
        edit: (controller) => controller
          ..setTilt(33 * _degree)
          ..setZoom(2),
      );

      expect(kept.size, const Size(754, 754));
      expect(kept.at(0, 0), _blue);
      expect(kept.at(1, 1), _blue);
    });

    testWidgets('takes a tilt that is nearly level to mean level', (
      tester,
    ) async {
      final controller = await loaded(tester);

      controller.setTilt(0.8 * _degree);
      expect(controller.rotation, 0);
      controller
        ..turnBy(1)
        ..setTilt(-0.7 * _degree);
      expect(controller.rotation, closeTo(math.pi / 2, 1e-9));

      // Any other angle is kept as it is, however small.
      controller.setTilt(1.5 * _degree);
      expect(controller.tilt, closeTo(1.5 * _degree, 1e-9));
      controller.setTilt(12 * _degree);
      // Past half a turn it comes round the other way.
      controller.turnBy(1);
      expect(controller.rotation, closeTo(-168 * _degree, 1e-9));
      expect(controller.tilt, closeTo(12 * _degree, 1e-9));
    });

    testWidgets('straightens by up to an eighth of a turn, on top of its '
        'quarter turns', (tester) async {
      final controller = await loaded(tester);

      controller.setTilt(-7 * _degree);
      expect(controller.rotation, closeTo(-7 * _degree, 1e-9));
      controller.turnBy(1);
      expect(controller.rotation, closeTo(83 * _degree, 1e-9));
      expect(controller.tilt, closeTo(-7 * _degree, 1e-9));

      // The slider's ends are as far as it goes.
      controller.setTilt(60 * _degree);
      expect(controller.tilt, PhotoCropController.maxTilt);
      expect(controller.rotation, closeTo(135 * _degree, 1e-9));
      // Close to level is taken to mean level.
      controller.setTilt(0.6 * _degree);
      expect(controller.tilt, 0);
    });

    testWidgets('turning grows the photo only as much as covers the frame, '
        'and gives it back', (tester) async {
      final controller = await loaded(tester);
      final upright = controller.drawnSize;

      controller.setTilt(30 * _degree);
      expect(controller.drawnSize.width, greaterThan(upright.width));
      expect(controller.zoom, PhotoCropController.minZoom);
      controller.setTilt(0);
      expect(controller.drawnSize, upright);
      expect(controller.edited, isFalse);

      // Zoomed in, there is photo to spare: it turns without changing size.
      controller.setZoom(2);
      final zoomed = controller.drawnSize;
      controller.setTilt(30 * _degree);
      expect(controller.drawnSize, zoomed);
      controller.turnBy(1);
      expect(controller.drawnSize, zoomed);
    });

    testWidgets('zooms and turns about the middle of the frame when a '
        'slider or button is used', (tester) async {
      final controller = await loaded(tester);
      controller.setZoom(2);
      _drag(controller, const Offset(30, 20));
      final middle = _under(controller, Offset.zero);

      controller.setZoom(2.6);
      expect(
        (_under(controller, Offset.zero) - middle).distance,
        lessThan(1e-6),
      );
      controller.setTilt(20 * _degree);
      expect(
        (_under(controller, Offset.zero) - middle).distance,
        lessThan(1e-6),
      );
      controller.turnBy(1);
      expect(
        (_under(controller, Offset.zero) - middle).distance,
        lessThan(1e-6),
      );
    });

    testWidgets('one finger moves the photo with the finger, and only moves '
        'it', (tester) async {
      final controller = await loaded(tester);
      controller.setZoom(2);

      controller
        ..startGesture(const Offset(10, 20))
        ..updateGesture(focal: const Offset(25, 5))
        // Each update is measured from where the finger started.
        ..updateGesture(focal: const Offset(40, -15));

      expect(
        (controller.offset - const Offset(30, -35)).distance,
        lessThan(1e-9),
      );
      expect(controller.zoom, closeTo(2, 1e-9));
      expect(controller.rotation, 0);
    });

    testWidgets('a pinch zooms about the fingers: the spot under them stays '
        'under them', (tester) async {
      final controller = await loaded(tester);
      controller.setZoom(1.5);
      const fingers = Offset(50, -30);
      final spot = _under(controller, fingers);

      controller
        ..startGesture(fingers)
        ..updateGesture(focal: fingers, scale: 1.2)
        ..updateGesture(focal: fingers, scale: 1.44);

      // The first few hundredths were the fingers settling.
      expect(controller.zoom, closeTo(1.5 * 1.4, 1e-9));
      expect((_under(controller, fingers) - spot).distance, lessThan(1e-6));
      // A pinch does not tilt the photo, however the fingers wobble.
      controller.updateGesture(focal: fingers, scale: 1.44, twist: 6 * _degree);
      expect(controller.rotation, 0);

      // The fingers can carry the spot along as they pinch.
      const carried = Offset(20, 10);
      controller.updateGesture(focal: carried, scale: 1.44);
      expect((_under(controller, carried) - spot).distance, lessThan(1e-6));

      // It stops at the largest and smallest sizes.
      controller.updateGesture(focal: fingers, scale: 9);
      expect(controller.zoom, PhotoCropController.maxZoom);
      controller.updateGesture(focal: fingers, scale: 0.01);
      expect(controller.zoom, PhotoCropController.minZoom);
    });

    testWidgets('zoom never reads a hair past its limit, whatever the photo', (
      tester,
    ) async {
      // Sizes whose division does not come out even.
      for (final (width, height) in [(900, 1600), (1000, 1333), (777, 1234)]) {
        final photo = (await tester.runAsync(() => _plain(width, height)))!;
        final controller = PhotoCropController(
          shape: const PhotoCropShape.idCard(),
        );
        addTearDown(controller.dispose);
        await tester.runAsync(() => controller.load(photo));

        for (final degrees in [0, 3, 11, 29, 45]) {
          controller
            ..setTilt(degrees * _degree)
            ..setZoom(PhotoCropController.maxZoom);
          expect(
            controller.zoom,
            inInclusiveRange(
              PhotoCropController.minZoom,
              PhotoCropController.maxZoom,
            ),
            reason: '$width by $height at $degrees°',
          );
        }
      }
    });

    testWidgets('a twist turns the photo about the fingers, without changing '
        'its size', (tester) async {
      final controller = await loaded(tester);
      controller.setZoom(2);
      const fingers = Offset(-40, 25);
      final spot = _under(controller, fingers);
      final size = controller.drawnSize;

      controller
        ..startGesture(fingers)
        ..updateGesture(focal: fingers, twist: 28 * _degree);

      // The first few degrees were the fingers settling.
      expect(controller.rotation, closeTo(20 * _degree, 1e-9));
      expect((_under(controller, fingers) - spot).distance, lessThan(1e-6));
      expect(controller.drawnSize, size);

      // Twisted back to nearly level, it is level.
      controller.updateGesture(focal: fingers, twist: 8.5 * _degree);
      expect(controller.rotation, 0);
      // A twist may be reported as nearly a whole turn the other way.
      controller.updateGesture(
        focal: fingers,
        twist: 28 * _degree - 2 * math.pi,
      );
      expect(controller.rotation, closeTo(20 * _degree, 1e-9));
      // And the other way, past a quarter turn.
      controller.updateGesture(focal: fingers, twist: -108 * _degree);
      expect(controller.rotation, closeTo(-100 * _degree, 1e-9));
    });

    testWidgets('a twist does not zoom, and a pinch at the end of the '
        'slider does not flip the slider over', (tester) async {
      final controller = await loaded(tester);
      final level = controller.drawnSize;

      // Twisted there and back in two goes, with fingers that also wobble.
      controller
        ..startGesture(Offset.zero)
        ..updateGesture(focal: Offset.zero, scale: 1.02, twist: 38 * _degree)
        ..startGesture(Offset.zero)
        ..updateGesture(focal: Offset.zero, scale: 0.99, twist: -38 * _degree);
      expect(controller.rotation, 0);
      expect(controller.drawnSize, level);
      expect(controller.edited, isFalse);

      controller
        ..setTilt(PhotoCropController.maxTilt)
        ..startGesture(Offset.zero)
        ..updateGesture(focal: Offset.zero, scale: 1.5, twist: 0.5 * _degree);
      expect(controller.tilt, PhotoCropController.maxTilt);
      expect(controller.rotation, closeTo(45 * _degree, 1e-9));
    });

    testWidgets('fingers already down when the photo arrives start from '
        'where they are, without a jump', (tester) async {
      final photo = (await tester.runAsync(() => _plain(600, 800)))!;
      final controller = PhotoCropController();
      addTearDown(controller.dispose);

      controller.startGesture(const Offset(60, 40));
      await tester.runAsync(() => controller.load(photo));
      controller.setZoom(2);

      controller.updateGesture(focal: const Offset(80, 10));
      expect(controller.offset, Offset.zero);
      controller.updateGesture(focal: const Offset(85, 4));
      expect(
        (controller.offset - const Offset(5, -6)).distance,
        lessThan(1e-9),
      );
    });

    testWidgets('keeps zoom within its limits and can be put back as it '
        'was', (tester) async {
      final photo = (await tester.runAsync(() => _plain(600, 800)))!;
      final controller = PhotoCropController();
      addTearDown(controller.dispose);
      expect(controller.edited, isFalse);
      // Nothing to change before a photo is loaded.
      controller
        ..flip()
        ..setTilt(1)
        ..turnBy(1)
        ..reset();
      expect(controller.edited, isFalse);

      await tester.runAsync(() => controller.load(photo));
      controller.setZoom(9);
      expect(controller.zoom, PhotoCropController.maxZoom);
      controller
        ..setZoom(0.2)
        ..flip()
        ..setTilt(40 * _degree);
      expect(controller.zoom, PhotoCropController.minZoom);
      expect(controller.edited, isTrue);

      controller.reset();
      expect(controller.zoom, PhotoCropController.minZoom);
      expect(controller.rotation, 0);
      expect(controller.flipped, isFalse);
      expect(controller.edited, isFalse);
    });
  });

  group('the photo editor on screen', () {
    setUpAll(loadAppFonts);

    // The sliders come alive once the picked photo has been decoded.
    final ready = find.byWidgetPredicate(
      (widget) => widget is Slider && widget.onChanged != null,
    );

    /// New ID card with a photo picked, so the editor is open.
    Future<void> openEditor(WidgetTester tester) async {
      tester.setScreenSize(const Size(390, 844));
      final photo = (await tester.runAsync(() => _plain(600, 800)))!;
      final container = createContainer(
        overrides: [photoPickerProvider.overrideWithValue(OnePhoto(photo))],
      );
      await tester.pumpApp(container);
      await tester.runAsync(() => signIn(container));
      container.read(routerProvider).go(AppRoutes.newCard);
      await tester.pumpAndSettle();
      await tester.tapAndWaitFor('Upload photo', ready);
    }

    double zoom(WidgetTester tester) =>
        tester.widget<Slider>(find.byType(Slider).first).value;
    double turn(WidgetTester tester) =>
        tester.widget<Slider>(find.byType(Slider).last).value;
    bool canReset(WidgetTester tester) =>
        tester
            .widget<SecondaryButton>(
              find.widgetWithText(SecondaryButton, 'Reset'),
            )
            .onPressed !=
        null;

    testWidgets('has a slider and buttons for each thing it can do, named '
        'for a screen reader', (tester) async {
      await openEditor(tester);

      expect(find.byType(Slider), findsNWidgets(2));
      for (final label in [
        'Zoom',
        'Zoom out',
        'Zoom in',
        'Straighten',
        'Turn left',
        'Turn right',
      ]) {
        expect(find.bySemanticsLabel(label), findsOneWidget, reason: label);
      }
      // What a slider is set to is said in words, with no symbols.
      final said = tester.widget<Slider>(find.byType(Slider).first);
      expect(said.semanticFormatterCallback!(1.25), '125 percent');
      final tilted = tester.widget<Slider>(find.byType(Slider).last);
      expect(tilted.semanticFormatterCallback!(-12 * _degree), '-12 degrees');
      // Nothing to put back yet.
      expect(canReset(tester), isFalse);

      // A quarter turn leaves the straightening slider where it was.
      await tester.tap(find.bySemanticsLabel('Turn right'));
      await tester.pump();
      expect(turn(tester), 0);
      expect(canReset(tester), isTrue);

      await tester.tap(find.bySemanticsLabel('Zoom in'));
      await tester.pump();
      expect(zoom(tester), closeTo(1.25, 1e-9));

      await tester.ensureVisible(find.text('Flip'));
      await tester.tap(find.text('Flip'));
      await tester.pump();
      expect(canReset(tester), isTrue);

      await tester.tap(find.text('Reset'));
      await tester.pump();
      expect((zoom(tester), turn(tester)), (1.0, 0.0));
      expect(canReset(tester), isFalse);
    });

    testWidgets('straightens to any angle with its slider', (tester) async {
      await openEditor(tester);

      // A third of the way from the middle towards the right end.
      final slider = find.byType(Slider).last;
      final reach = tester.getSize(slider).width / 2;
      await tester.tapAt(tester.getCenter(slider) + Offset(reach / 3, 0));
      await tester.pump();

      expect(turn(tester) / _degree, inInclusiveRange(10, 20));
      // Turning is all it did.
      expect(zoom(tester), 1.0);
    });

    testWidgets('a finger dragged on the photo moves the photo, and the page '
        'stays where it is', (tester) async {
      await openEditor(tester);
      final photo = find.descendant(
        of: find.byType(PhotoCropper),
        matching: find.byType(CustomPaint),
      );
      final page = Scrollable.of(tester.element(find.byType(PhotoCropper)));
      final scrolled = page.position.pixels;

      // Up and down is the way the page would scroll.
      await tester.drag(photo.first, const Offset(0, -24));
      await tester.pump();

      expect(page.position.pixels, scrolled);
      expect(canReset(tester), isTrue);
    });

    testWidgets('two fingers spread on the photo zoom it', (tester) async {
      await openEditor(tester);
      final middle = tester.getCenter(
        find
            .descendant(
              of: find.byType(PhotoCropper),
              matching: find.byType(CustomPaint),
            )
            .first,
      );

      final left = await tester.startGesture(
        middle - const Offset(30, 0),
        pointer: 7,
      );
      final right = await tester.startGesture(
        middle + const Offset(30, 0),
        pointer: 8,
      );
      await left.moveBy(const Offset(-15, 0));
      await right.moveBy(const Offset(15, 0));
      await tester.pump();
      await left.up();
      await right.up();
      await tester.pump();

      expect(zoom(tester), closeTo(1.46, 0.01));
      // Straight apart: nothing turned.
      expect(turn(tester), 0);
    });

    testWidgets('a second finger put down or lifted mid-drag does not make '
        'the photo jump', (tester) async {
      await openEditor(tester);
      final crop = tester.widget<PhotoCropper>(find.byType(PhotoCropper));
      final controller = crop.controller..setZoom(2);
      await tester.pump();
      final middle = tester.getCenter(
        find
            .descendant(
              of: find.byType(PhotoCropper),
              matching: find.byType(CustomPaint),
            )
            .first,
      );

      final one = await tester.startGesture(middle, pointer: 7);
      await one.moveBy(const Offset(0, 30));
      await tester.pump();
      final dragged = controller.offset;
      expect(dragged.dy, closeTo(30, 1e-6));

      // A second finger lands, and the first lets go: nothing moves.
      final two = await tester.startGesture(
        middle + const Offset(60, 0),
        pointer: 8,
      );
      await tester.pump();
      await one.up();
      await tester.pump();
      expect((controller.offset - dragged).distance, lessThan(1e-6));
      expect(controller.zoom, closeTo(2, 1e-9));

      // The finger left carries on from there: its first movement is where
      // the new drag starts, and the photo follows it after that.
      await two.moveBy(const Offset(-1, 0));
      await tester.pump();
      expect((controller.offset - dragged).distance, lessThan(1e-6));
      await two.moveBy(const Offset(-12, 0));
      await tester.pump();
      expect(
        (controller.offset - (dragged + const Offset(-12, 0))).distance,
        lessThan(1e-6),
      );
      await two.up();
    });

    testWidgets('two fingers twisted on the photo straighten it, and a '
        'small wobble does not', (tester) async {
      await openEditor(tester);
      final middle = tester.getCenter(
        find
            .descendant(
              of: find.byType(PhotoCropper),
              matching: find.byType(CustomPaint),
            )
            .first,
      );
      // Two fingers 80 apart, turned about their middle by [degrees].
      Future<void> twist(double degrees) async {
        final angle = degrees * _degree;
        final one = await tester.startGesture(
          middle - const Offset(40, 0),
          pointer: 7,
        );
        final two = await tester.startGesture(
          middle + const Offset(40, 0),
          pointer: 8,
        );
        for (var step = 1; step <= 10; step++) {
          final part =
              Offset(math.cos(angle * step / 10), math.sin(angle * step / 10)) *
              40;
          await one.moveTo(middle - part);
          await two.moveTo(middle + part);
        }
        await tester.pump();
        await one.up();
        await two.up();
        await tester.pump();
      }

      await twist(5);
      expect(turn(tester), 0);
      expect(zoom(tester), 1.0);

      await twist(20);
      expect(turn(tester) / _degree, closeTo(12, 0.5));
      // Turning did not zoom.
      expect(zoom(tester), 1.0);
    });

    testWidgets('lays out with its controls in Tibetan with Simple Mode', (
      tester,
    ) async {
      tester.setScreenSize(const Size(390, 844));
      final photo = (await tester.runAsync(() => _plain(600, 800)))!;
      final container = createContainer(
        overrides: [photoPickerProvider.overrideWithValue(OnePhoto(photo))],
      );
      await tester.pumpApp(container);
      await tester.runAsync(() => signIn(container));
      container.read(preferencesProvider.notifier)
        ..setLanguage(AppLanguage.tibetan)
        ..setSimpleMode(true);
      container.read(routerProvider).go(AppRoutes.newCard);
      await tester.pumpAndSettle();
      // Picked through the view model: the button's words are not English.
      await tester.runAsync(() async {
        await container
            .read(cardFormViewModelProvider(null).notifier)
            .pickPhoto(PhotoOrigin.gallery);
        final patience = Stopwatch()..start();
        while (ready.evaluate().isEmpty &&
            patience.elapsed < const Duration(seconds: 10)) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
          await tester.pump();
        }
      });
      await tester.pumpAndSettle();

      expect(ready, findsNWidgets(2));
      expect(tester.takeException(), isNull);
    });
  });
}

/// Turns the photo to [degrees]: by quarters, then the tilt that is left.
void _turnTo(PhotoCropController controller, int degrees) {
  final quarters = (degrees / 90).round();
  controller
    ..turnBy(quarters)
    ..setTilt((degrees - quarters * 90) * _degree);
}

/// Moves the photo as one finger would, by [delta].
void _drag(PhotoCropController controller, Offset delta) => controller
  ..startGesture(Offset.zero)
  ..updateGesture(focal: delta);

/// The spot of the photo shown at [at], a point of the window measured
/// from its middle: in photo pixels from the photo's own middle.
Offset _under(PhotoCropController controller, Offset at) {
  final arm = at - controller.offset;
  final cos = math.cos(-controller.rotation);
  final sin = math.sin(-controller.rotation);
  final scale = controller.drawnSize.width / controller.image!.width;
  return Offset(arm.dx * cos - arm.dy * sin, arm.dx * sin + arm.dy * cos) /
      scale;
}

/// The pixels of an exported photo.
class _Pixels {
  _Pixels(this.size, this._rgba);

  final Size size;
  final ByteData _rgba;

  static Future<_Pixels> of(Uint8List png) async {
    final frame = await (await ui.instantiateImageCodec(png)).getNextFrame();
    final image = frame.image;
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    return _Pixels(
      Size(image.width.toDouble(), image.height.toDouble()),
      data!,
    );
  }

  /// The colour at [x], [y], each from 0 (left, top) to 1 (right, bottom),
  /// rounded to the nearer of the two test colours, or clear if it is empty.
  Color at(double x, double y) {
    final column = (x * (size.width - 1)).round();
    final row = (y * (size.height - 1)).round();
    final offset = (row * size.width.toInt() + column) * 4;
    if (_rgba.getUint8(offset + 3) < 250) return const Color(0x00000000);
    return _rgba.getUint8(offset) > _rgba.getUint8(offset + 2) ? _red : _blue;
  }
}

/// A photo that is one colour all over.
Future<Uint8List> _plain(int width, int height) =>
    _paint(width, height, (canvas, box) {
      canvas.drawRect(box, Paint()..color = _blue);
    });

/// A photo in two halves: red then blue, side by side or one above the other.
Future<Uint8List> _split(int width, int height, {bool topAndBottom = false}) =>
    _paint(width, height, (canvas, box) {
      canvas.drawRect(box, Paint()..color = _blue);
      canvas.drawRect(
        topAndBottom
            ? Rect.fromLTWH(0, 0, box.width, box.height / 2)
            : Rect.fromLTWH(0, 0, box.width / 2, box.height),
        Paint()..color = _red,
      );
    });

Future<Uint8List> _paint(
  int width,
  int height,
  void Function(Canvas canvas, Rect box) draw,
) async {
  final recorder = ui.PictureRecorder();
  draw(
    Canvas(recorder),
    Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
  );
  final image = await recorder.endRecording().toImage(width, height);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  return data!.buffer.asUint8List();
}
