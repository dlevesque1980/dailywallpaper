#!/usr/bin/env dart

import 'dart:io';

void main(List<String> args) async {
  final mode = args.isNotEmpty ? args[0] : 'unit';

  switch (mode) {
    case 'unit':
      print('🧪 Exécution des tests unitaires rapides...');
      await runTests(['--tags=unit']);
      break;

    case 'integration':
      print('🔗 Exécution des tests d\'intégration...');
      await runTests(['--tags=integration']);
      break;

    case 'all':
      print('🚀 Exécution de tous les tests...');
      await runTests([]);
      break;

    case 'fast':
      print('⚡ Tests rapides seulement (< 5 min)...');
      await runTests(['--tags=unit', '--concurrency=4']);
      break;

    default:
      print('Usage: dart test_runner.dart [unit|integration|all|fast]');
      print('');
      print('Modes disponibles:');
      print('  unit        - Tests unitaires rapides (~2 min)');
      print('  integration - Tests d\'intégration (~3 min)');
      print('  all         - Tous les tests (~5 min)');
      print('  fast        - Tests parallèles rapides (~1 min)');
      exit(1);
  }
}

Future<void> runTests(List<String> args) async {
  final stopwatch = Stopwatch()..start();

  final result = await Process.run(
    'flutter',
    ['test', ...args],
    workingDirectory: Directory.current.path,
  );

  stopwatch.stop();

  print(result.stdout);
  if (result.stderr.isNotEmpty) {
    print('Erreurs:');
    print(result.stderr);
  }

  print('\n⏱️  Temps d\'exécution: ${stopwatch.elapsed}');

  if (result.exitCode == 0) {
    print('✅ Tous les tests ont réussi !');
  } else {
    print('❌ Certains tests ont échoué (code: ${result.exitCode})');
    exit(result.exitCode);
  }
}
