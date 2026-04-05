/// This is for renaming projects bungleId, name , organization. But I do not use this
///
/// Im using rename package
///
/// for changing app's name run in terminal
///
///   rename setAppName --targets ios,android,macos,windows,linux,web --value "YourAppName"
///
/// for changing appBundle run:
///
///   rename setBundleId --targets ios,android,macos,windows,linux,web --value "com.example.bundleId"

// ignore_for_file: dangling_library_doc_comments

import 'dart:io' as io;

import 'package:collection/collection.dart';
import 'package:path/path.dart' as p;

// then change after renaming you project, after running:
// dart run tool/dart/rename_project.dart --name="qqq" --organization="www" --description="eee"
const String _defaultName = 'accessandrefreshtoken'; // current app's defaultName
const String _defaultOrganization = 'dev.flutter';
const String _defaultDescription = '_description';

/// dart run tool/dart/rename_project.dart --name="flutter_project_name" --organization="dev.flutter" --description="flutter_desc"
void main([List<String>? args]) {
  if (args == null || args.isEmpty) _throwArguments();
  String? extractArg(String key) {
    final value = args.firstWhereOrNull((e) => e.startsWith(key));
    if (value == null) return null;
    return RegExp(
      r'[\d\w\.\-\_ ]+',
    ).allMatches(value.substring(key.length)).map((e) => e.group(0)).join().trim();
  }

  final name = extractArg('--name');
  final org = extractArg('--organization');
  final desc = extractArg('--description');
  if (name == null || org == null || desc == null) _throwArguments();
  _renameDirectory(_defaultName, name);
  _changeContent([
    (from: _defaultName, to: name),
    (from: _defaultOrganization, to: org),
    (from: _defaultDescription, to: desc),
  ]);
}

Never _throwArguments() {
  io.stderr.writeln(
    'Pass arguments: '
    '--name="name" '
    '--organization="org.domain" '
    '--description="description"',
  );
  io.exit(1);
}

Iterable<io.FileSystemEntity> _recursiveDirectories(io.Directory directory) sync* {
  const excludeFiles = <String>{'README.md', 'rename_project.dart'};
  const excludeDirs = <String>{
    'Pods',
    '.pub-cache',
    '.dart_tool',
    'build',
    '.gradle',
    '.idea',
    'node_modules',
  };
  const includeExtensions = <String>{
    '.dart',
    '.yaml',
    '.gradle',
    '.xml',
    '.kt',
    '.plist',
    '.txt',
    '.cc',
    '.cpp',
    '.rc',
    '.xcconfig',
    '.pbxproj',
    '.xcscheme',
    '.html',
    '.json',
  };
  for (final e in directory.listSync(recursive: false, followLinks: false)) {
    if (p.basename(e.path).startsWith('.')) continue;
    if (e is io.File) {
      if (!includeExtensions.contains(p.extension(e.path))) continue;
      if (excludeFiles.contains(p.basename(e.path))) continue;
      yield e;
    } else if (e is io.Directory) {
      if (excludeDirs.contains(p.basename(e.path))) continue;
      yield e;
      yield* _recursiveDirectories(e);
    }
  }
}

void _renameDirectory(String from, String to) => _recursiveDirectories(io.Directory.current)
    .whereType<io.Directory>()
    .toList(growable: false)
    .where((dir) => p.basename(dir.path) == from)
    .forEach((dir) => dir.renameSync(p.join(p.dirname(dir.path), to)));

void _changeContent(List<({String from, String to})> pairs) =>
    _recursiveDirectories(io.Directory.current).whereType<io.File>().forEach((e) {
      var content = e.readAsStringSync();
      var changed = false;
      for (final pair in pairs) {
        if (!content.contains(pair.from)) continue;
        content = content.replaceAll(pair.from, pair.to);
        changed = true;
      }
      if (!changed) return;
      e.writeAsStringSync(content);
    });
