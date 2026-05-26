import 'dart:io';
import 'package:path_provider/path_provider.dart';

abstract class UpdateStrategy {
  String get type;
  Future<void> install(String installerPath, {String? expectedBinary});
  Future<bool> validateInstaller(String path);
}

class FullInstallerStrategy implements UpdateStrategy {
  @override
  String get type => 'installer';

  @override
  Future<bool> validateInstaller(String path) async {
    final file = File(path);
    if (!await file.exists()) return false;
    final size = await file.length();
    if (size < 1024 * 1024) return false;
    if (Platform.isWindows && !path.endsWith('.exe')) return false;
    return true;
  }

  @override
  Future<void> install(String installerPath, {String? expectedBinary}) async {
    final file = File(installerPath);
    if (!await file.exists()) {
      throw Exception('Installer not found');
    }

    if (Platform.isWindows) {
      final result = await Process.run(
        installerPath,
        ['/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART'],
        runInShell: true,
      );
      if (result.exitCode != 0) {
        throw Exception('Installer failed with exit code ${result.exitCode}');
      }
    } else {
      throw UnsupportedError('Full installer not supported on this platform');
    }
  }
}

class PortableZipStrategy implements UpdateStrategy {
  @override
  String get type => 'portable';

  @override
  Future<bool> validateInstaller(String path) async {
    final file = File(path);
    if (!await file.exists()) return false;
    final size = await file.length();
    if (size < 1024 * 1024) return false;
    return true;
  }

  @override
  Future<void> install(String archivePath, {String? expectedBinary}) async {
    final file = File(archivePath);
    if (!await file.exists()) {
      throw Exception('Archive not found');
    }

    if (Platform.isWindows && archivePath.endsWith('.zip')) {
      final dir = await getApplicationSupportDirectory();
      final extractDir = '${dir.path}/portable_update';
      final extractDirectory = Directory(extractDir);
      if (await extractDirectory.exists()) {
        await extractDirectory.delete(recursive: true);
      }
      await extractDirectory.create(recursive: true);

      await Process.run(
        'powershell',
        ['Expand-Archive', '-Path', archivePath, '-DestinationPath', extractDir, '-Force'],
        runInShell: true,
      );

      final appDir = Directory(extractDir);
      final files = await appDir.list(recursive: true).toList();
      bool found = false;
      for (final f in files) {
        if (f is File && (expectedBinary == null || f.path.endsWith(expectedBinary))) {
          final targetDir = Directory.current;
          await f.copy('${targetDir.path}/${f.path.split('/').last}');
          found = true;
        }
      }

      if (await extractDirectory.exists()) {
        await extractDirectory.delete(recursive: true);
      }

      if (!found) {
        throw Exception('Binary not found in archive');
      }
    } else if (Platform.isLinux && archivePath.endsWith('.tar.gz')) {
      final dir = await getApplicationSupportDirectory();
      final extractDir = '${dir.path}/extracted';
      final extractDirectory = Directory(extractDir);
      if (await extractDirectory.exists()) {
        await extractDirectory.delete(recursive: true);
      }
      await extractDirectory.create(recursive: true);

      final result = await Process.run(
        'tar',
        ['-xzf', archivePath, '-C', extractDir],
        runInShell: true,
      );
      if (result.exitCode != 0) {
        if (await extractDirectory.exists()) {
          await extractDirectory.delete(recursive: true);
        }
        throw Exception('Extraction failed with exit code ${result.exitCode}');
      }

      final appDir = Directory(extractDir);
      final extractedFiles = await appDir.list(recursive: true).toList();
      bool binaryCopied = false;
      for (final f in extractedFiles) {
        if (f is File) {
          final relativePath = f.path.replaceAll('${appDir.path}/', '');
          if (expectedBinary == null || relativePath == expectedBinary) {
            final binaryPath = '${Platform.environment['HOME'] ?? '/opt'}/darsakai/darsak_desktop';
            await f.copy(binaryPath);
            await Process.run('chmod', ['+x', binaryPath]);
            binaryCopied = true;
          }
        }
      }

      if (await extractDirectory.exists()) {
        await extractDirectory.delete(recursive: true);
      }

      if (!binaryCopied) {
        throw Exception('Binary not found in archive');
      }
    } else {
      throw UnsupportedError('Unsupported archive format for this platform');
    }
  }
}

UpdateStrategy createUpdateStrategy() {
  if (Platform.isWindows) {
    return FullInstallerStrategy();
  }
  return PortableZipStrategy();
}
