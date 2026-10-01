import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/feedback/toast_host.dart';
import '../core/layout/responsive.dart';
import '../core/theme/accent_preset.dart';
import '../core/theme/app_theme.dart';
import '../features/settings/domain/app_preferences.dart';
import '../features/settings/presentation/view_models/preferences_view_model.dart';
import '../features/temple/presentation/view_models/temple_session.dart';
import '../l10n/generated/app_localizations.dart';
import 'router/app_router.dart';

/// The root widget: wires the router, theme, language and text scale to the
/// preferences and the current temple.
class NorbuFlowApp extends ConsumerWidget {
  const NorbuFlowApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preferences = ref.watch(preferencesProvider);
    final accent = ref.watch(
      currentTempleProvider.select(
        (temple) => temple?.accent ?? AccentPreset.maroon,
      ),
    );
    final tibetan = preferences.language == AppLanguage.tibetan;
    final scale =
        (tibetan ? AppTheme.tibetanTextScale : 1.0) *
        (preferences.simpleMode ? AppTheme.simpleModeTextScale : 1.0);

    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context).appName,
      debugShowCheckedModeBanner: false,
      routerConfig: ref.watch(routerProvider),
      locale: ref.watch(localeProvider),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        _TibetanFallbackDelegate<MaterialLocalizations>(
          DefaultMaterialLocalizations.delegate,
        ),
        _TibetanFallbackDelegate<WidgetsLocalizations>(
          DefaultWidgetsLocalizations.delegate,
        ),
        _TibetanFallbackDelegate<CupertinoLocalizations>(
          DefaultCupertinoLocalizations.delegate,
        ),
      ],
      theme: AppTheme.build(
        brightness: preferences.darkMode ? Brightness.dark : Brightness.light,
        accent: accent,
        tibetan: tibetan,
      ),
      builder: (context, child) {
        // The app's own scale (Tibetan, Simple Mode) multiplies the device's
        // accessibility text size rather than replacing it.
        final system = MediaQuery.textScalerOf(context).scale(1);
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(clampTextScale(system * scale)),
          ),
          // Default status-bar icons for screens that sit on the page
          // background. Screens with an accent header (splash, the app
          // shell) declare their own region, which takes precedence.
          child: AnnotatedRegion<SystemUiOverlayStyle>(
            value: preferences.darkMode
                ? SystemUiOverlayStyle.light
                : SystemUiOverlayStyle.dark,
            child: ToastHost(child: child ?? const SizedBox.shrink()),
          ),
        );
      },
    );
  }
}

/// Flutter ships no Tibetan translations for its own widgets (date pickers,
/// tooltips, text-selection menus). This serves the English ones when the
/// interface is in Tibetan, so those widgets keep working.
class _TibetanFallbackDelegate<T> extends LocalizationsDelegate<T> {
  const _TibetanFallbackDelegate(this._english);

  final LocalizationsDelegate<T> _english;

  @override
  bool isSupported(Locale locale) =>
      locale.languageCode == AppLanguage.tibetan.code;

  @override
  Future<T> load(Locale locale) => _english.load(const Locale('en'));

  @override
  bool shouldReload(_TibetanFallbackDelegate<T> old) => false;
}
