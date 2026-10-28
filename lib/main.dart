import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/app_state.dart';
import 'ui/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  LicenseRegistry.addLicense(_licenses);
  try {
    await AppState.instance.init();
  } catch (e, stack) {
    debugPrint('BoxPilot failed to start: $e\n$stack');
    runApp(_StartupError(message: '$e'));
    return;
  }
  runApp(const BoxPilotApp());
}

/// BoxPilot's own licence and the embedded core's, for the licences page.
Stream<LicenseEntry> _licenses() async* {
  yield LicenseEntryWithLineBreaks(['BoxPilot'], await rootBundle.loadString('assets/licenses/boxpilot.txt'));
  yield LicenseEntryWithLineBreaks(['sing-box'], await rootBundle.loadString('assets/licenses/sing-box.txt'));
}

/// Shown when the engine cannot start (e.g. the data folder is unreadable).
class _StartupError extends StatelessWidget {
  const _StartupError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48),
                const SizedBox(height: 16),
                const Text('BoxPilot could not start', style: TextStyle(fontSize: 20)),
                const SizedBox(height: 8),
                SelectableText(message, textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
