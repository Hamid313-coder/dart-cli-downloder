import 'dart:io';

import 'package:args/args.dart';
import 'package:dio/dio.dart';
import 'package:validators/validators.dart';

void main(List<String> args) async {
  try {
    final argParser = buildParser();

    final results = argParser.parse(args);
    if (results.wasParsed('help')) {
      printUsage(argParser);
      return;
    }

    if (args.length > 1) {
      throw 'Just one argument is allowed';
    }
    if (args.isEmpty) {
      printUsage(argParser);
      return;
    }

    if (!isURL(results.arguments.first)) {
      throw 'Not a valid URL';
    }
    final filePath = await download(results.arguments.first);

    print('\nFile downloaded to "$filePath"');
  } catch (e) {
    print(e.toString());
  }
}

ArgParser buildParser() {
  return ArgParser()
    ..addFlag(
      'help',
      abbr: 'h',
      negatable: false,
    );
}

void printUsage(ArgParser argParser) {
  print('Usage: downld [URL]');
  print(argParser.usage);
}

Future<String> download(String url) async {
  try {
    final dio = Dio();

    final directory = getDownloadsDirectory();

    final savePath = '${directory.path}\\${Uri.parse(url).pathSegments.last}';

    final response = await dio.download(
      url,
      savePath,
      options: Options(
        headers: {HttpHeaders.acceptEncodingHeader: '*'}, // Disable gzip
      ),
      onReceiveProgress: (received, total) {
        if (total <= -1) return;

        final progress = ((received / total) * 100).toInt();
        showProgress(progress);
      },
    );

    final contentType =
        (response.headers.map['content-type'] as List)[0] as String;

    final fileExtension = contentType.split('/').last;

    final newSavePath = renameIfNoExtenion(savePath, fileExtension);

    if (newSavePath != null) return newSavePath;

    return savePath;
  } catch (e) {
    rethrow;
  }
}

Directory getDownloadsDirectory() {
  final userProfile = Platform.environment['USERPROFILE'];
  if (userProfile != null) {
    final downloadsDirectory = '$userProfile\\Downloads';
    final dir = Directory(downloadsDirectory);
    dir.createSync(recursive: true);
    return dir;
  }
  return Directory.current;
}

void showProgress(int progress) {
  try {
    assert(
        progress >= 0 && progress <= 100, 'Progress must be between 0 and 100');
    const int total = 100;
    const int barLength = 40;

    if (progress > total) progress = total;

    // Calculate the number of "=" signs based on progress
    int filledLength = (barLength * progress) ~/ total;
    String bar = '=' * filledLength + ' ' * (barLength - filledLength);

    stdout.write('\r[$bar] $progress%');
  } catch (e) {
    rethrow;
  }
}

String? renameIfNoExtenion(String filePath, String extenion) {
  final fileName = filePath.split('\\').last;

  if (fileName.contains('.')) return null;

  final file = File(filePath);
  var path = file.path;
  var lastSeparator = path.lastIndexOf(Platform.pathSeparator);
  var newPath = '${path.substring(0, lastSeparator + 1)}$fileName.$extenion';
  return file.renameSync(newPath).path;
}
