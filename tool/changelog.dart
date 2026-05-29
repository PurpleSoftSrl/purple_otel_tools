#!/usr/bin/env dart
///
/// CHANGELOG Generator — reads conventional commits, outputs categorized entries.
///
/// Usage:
///   dart run tool/changelog.dart                        # all packages
///   dart run tool/changelog.dart --package purple_otel_sdk

import 'dart:convert';
import 'dart:io';

void main(List<String> args) async {
  final pkgFilter = args.contains('--package') ? args[args.indexOf('--package') + 1] : null;

  for (final pkg in _findPackages()) {
    if (pkgFilter != null && pkg.name != pkgFilter) continue;

    final commits = await _getCommits(pkg.name);
    if (commits.isEmpty) continue;

    stdout.writeln('\n## ${pkg.name}');
    for (final c in commits) {
      stdout.writeln('  ${c}');
    }
  }
}

List<_Pkg> _findPackages() {
  final root = Directory.current.parent.parent.parent.path;
  final shared = '$root/packages/shared';
  if (!Directory(shared).existsSync()) return [];
  return Directory(shared)
      .listSync()
      .whereType<Directory>()
      .where((d) => File('${d.path}/pubspec.yaml').existsSync())
      .map((d) => _Pkg(d.path.split(Platform.pathSeparator).last))
      .toList();
}

Future<List<String>> _getCommits(String pkg) async {
  final r = await Process.run('git', ['log', '--pretty=format:%s', '--', 'packages/shared/$pkg'], runInShell: true);
  return LineSplitter.split(r.stdout as String).where((l) => l.isNotEmpty).toList();
}

class _Pkg {
  final String name;
  _Pkg(this.name);
}
