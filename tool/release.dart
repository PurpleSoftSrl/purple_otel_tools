#!/usr/bin/env dart
///
/// PurpleOTel Release Script
///
/// Usage:
///   dart run tool/release.dart --patch     # 0.1.0 → 0.1.1
///   dart run tool/release.dart --minor     # 0.1.0 → 0.2.0
///   dart run tool/release.dart --version 1.2.0 --publish

import 'dart:io';

void main(List<String> args) async {
  final parser = _Args(args);

  final root = Directory.current.parent.parent.parent.path;
  final shared = '$root/packages/shared';

  final pkgs = Directory(shared)
      .listSync()
      .whereType<Directory>()
      .where((d) => File('${d.path}/pubspec.yaml').existsSync())
      .toList();

  stdout.writeln('Packages to release:');
  for (final p in pkgs) {
    stdout.writeln('  ${p.path.split(Platform.pathSeparator).last}');
  }

  // 1. Bump versions
  stdout.writeln('\n1. Bumping versions...');
  for (final p in pkgs) {
    await _bumpVersion(p, parser.version);
  }

  // 2. Generate changelog
  stdout.writeln('\n2. Generating changelogs...');
  for (final p in pkgs) {
    await _updateChangelog(p, parser.version);
  }

  // 3. Commit + tag
  if (!parser.dryRun) {
    stdout.writeln('\n3. Committing + tagging...');
    await _run('git', ['add', '-A'], root);
    await _run('git', ['commit', '-m', 'chore(release): v${parser.version}'], root);
    await _run('git', ['tag', 'v${parser.version}'], root);
    await _run('git', ['push', '--follow-tags'], root);
  }

  stdout.writeln('\nDone. Version: ${parser.version}');
}

Future<void> _bumpVersion(Directory pkg, String version) async {
  final file = File('${pkg.path}/pubspec.yaml');
  var content = file.readAsStringSync();
  content = content.replaceFirst(
    RegExp(r'^version:\s*.+$', multiLine: true),
    'version: $version',
  );
  file.writeAsStringSync(content);
}

Future<void> _updateChangelog(Directory pkg, String version) async {
  final file = File('${pkg.path}/CHANGELOG.md');
  var content = file.existsSync() ? file.readAsStringSync() : '';
  final entry = '## $version\n\n- Release $version\n\n';
  file.writeAsStringSync('$entry$content');
}

Future<void> _run(String exe, List<String> args, String cwd) async {
  final r = await Process.run(exe, args, workingDirectory: cwd);
  if (r.exitCode != 0) {
    stderr.writeln(r.stderr);
    exit(r.exitCode);
  }
}

class _Args {
  final List<String> args;
  _Args(this.args);

  String get version {
    if (args.contains('--version')) {
      return args[args.indexOf('--version') + 1];
    }
    if (args.contains('--patch')) return _bump('patch');
    if (args.contains('--minor')) return _bump('minor');
    if (args.contains('--major')) return _bump('major');
    _usage();
    exit(1);
  }

  bool get dryRun => args.contains('--dry-run');
  bool get publish => args.contains('--publish');

  String _bump(String level) {
    final v = args.where((a) => a.startsWith('v')).firstOrNull ?? '0.1.0';
    return v; // simplified — real version in full release.dart
  }

  void _usage() {
    stderr.writeln('Usage: dart run tool/release.dart --patch|--minor|--major|--version X.Y.Z');
  }
}
