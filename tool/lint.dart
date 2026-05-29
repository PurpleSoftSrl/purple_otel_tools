#!/usr/bin/env dart
import 'dart:io';

Future<void> main() async {
  final hasErrors = await _runAll();
  if (hasErrors) exit(1);
}

Future<bool> _runAll() async {
  var errors = false;

  final packages = _findPackages();
  _info('Found ${packages.length} packages');

  _info('');
  _info('=== dart format ===');
  if (await _runAnalyzer(packages, 'format')) errors = true;

  _info('');
  _info('=== dart fix --apply ===');
  if (await _runAnalyzer(packages, 'fix')) errors = true;

  _info('');
  _info('=== dart analyze ===');
  if (await _runAnalyzer(packages, 'analyze')) errors = true;

  if (errors) {
    _error('Some packages have issues — check output above');
  } else {
    _ok('All packages clean — no issues found');
  }

  return errors;
}

Future<bool> _runAnalyzer(List<_Package> packages, String command) async {
  var failed = 0;
  for (final pkg in packages) {
    final ok = await _run(command, pkg);
    if (!ok) failed++;
  }
  if (failed > 0) {
    _warn('$failed/${packages.length} packages have issues');
  }
  return failed > 0;
}

Future<bool> _run(String command, _Package pkg) async {
  switch (command) {
    case 'format':
      final result = await Process.run(
        'dart',
        ['format', '--output=none', '--set-exit-if-changed', '.'],
        workingDirectory: pkg.path,
      );
      if (result.exitCode != 0) {
        _warn('${pkg.name}: formatting issues (run: cd ${pkg.name} && dart format .)');
        return false;
      }
      break;

    case 'fix':
      final result = await Process.run(
        'dart',
        ['fix', '--apply', '.'],
        workingDirectory: pkg.path,
      );
      if (result.exitCode != 0) {
        _warn('${pkg.name}: fix issues');
        return false;
      }
      break;

    case 'analyze':
      final result = await Process.run(
        'dart',
        ['analyze', '.'],
        workingDirectory: pkg.path,
      );
      if (result.exitCode != 0) {
        _warn('${pkg.name}: has analysis issues');
        return false;
      }
      break;
  }

  _ok(pkg.name);
  return true;
}

List<_Package> _findPackages() {
  final root = Directory.current.parent.parent.parent.path;
  final shared = Directory('$root/packages/shared');
  if (!shared.existsSync()) return [];

  return shared
      .listSync()
      .whereType<Directory>()
      .where((d) => File('${d.path}/pubspec.yaml').existsSync())
      .map((d) => _Package(
            name: d.path.split(Platform.pathSeparator).last,
            path: d.path,
          ))
      .toList()
    ..sort((a, b) => a.name.compareTo(b.name));
}

void _info(String msg) => stdout.writeln('\x1B[34m[check]\x1B[0m $msg');
void _ok(String msg) => stdout.writeln('  \x1B[32mOK\x1B[0m  $msg');
void _warn(String msg) => stdout.writeln('  \x1B[33mWARN\x1B[0m $msg');
void _error(String msg) => stderr.writeln('\x1B[31m$msg\x1B[0m');

class _Package {
  final String name;
  final String path;
  _Package({required this.name, required this.path});
}
