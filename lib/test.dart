


import 'dart:convert';
import 'dart:io';
import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:flutter/services.dart' show rootBundle;
import 'package:desktop_drop/desktop_drop.dart';
import 'package:desktop_window/desktop_window.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Устанавливаем фиксированный размер окна 300x300 пикселей
  await DesktopWindow.setWindowSize(const Size(400, 300));
  await DesktopWindow.setMinWindowSize(const Size(400, 300));
  await DesktopWindow.setMaxWindowSize(const Size(400, 300));
  runApp(MyApp());

}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: FileLauncherPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class FileLauncherPage extends StatefulWidget {
  @override
  _FileLauncherPageState createState() => _FileLauncherPageState();
}

class _FileLauncherPageState extends State<FileLauncherPage> {
  String? elementPath;
  bool isDragging = false;
  Map<String, String>? scriptMapping;
  String msg="";

  @override
  void initState() {
    super.initState();
    _loadScriptMapping();
  }

  Future<void> _loadScriptMapping() async {
    try {
      // Загрузка JSON-файла из assets
      String jsonString = await rootBundle.loadString('assets/scenario_cmd.json');
      setState(() {
        scriptMapping = Map<String, String>.from(json.decode(jsonString));
      });
    } catch (e) {
      msg='Error when enabling script mapping: $e';
      print('Ошибка при загрузке маппинга скриптов: $e');
    }
  }

  void launchPythonScript(String elementPath) async {
    if (scriptMapping == null) {
      msg='Script mapping is not loaded.';
      print('Маппинг скриптов не загружен.');
      return;
    }

    // Проверяем, файл это или папка
    FileSystemEntity entity = FileSystemEntity.typeSync(elementPath) == FileSystemEntityType.directory
        ? Directory(elementPath)
        : File(elementPath);

    String? scriptName;

    if (entity is File) {
      String fileExtension = path.extension(elementPath);
      scriptName = scriptMapping![fileExtension];
      if (scriptName == null) {
        msg='Unknown file extension: $fileExtension';
        print('Неизвестное расширение файла: $fileExtension');
        return;
      }
    } else if (entity is Directory) {
      scriptName = scriptMapping!["directory"];
      if (scriptName == null) {
        msg='The script for the folders is not specified.';
        print('Скрипт для папок не указан.');
        return;
      }
    } else {
      msg='Unknown element type: $elementPath';
      print('Неизвестный тип элемента: $elementPath');
      return;
    }

    try {
      // Запуск Python скрипта с передачей пути к элементу
      final process = await Process.start(
        'python',
        [scriptName],
        workingDirectory: Directory.current.path,
      );

      // Отправляем путь как ввод в процессе
      process.stdin.writeln(elementPath);

      // Получаем результат выполнения
      final output = await process.stdout.transform(SystemEncoding().decoder).join();
      final error = await process.stderr.transform(SystemEncoding().decoder).join();

      if (error.isEmpty) {
        msg='Result: $output';
        print('Результат: $output');
      } else {
        msg='Error: $error';
        print('Ошибка: $error');
      }

      await process.stdin.close();
    } catch (e) {
      msg='Error when running the script: $e';
      print('Ошибка при запуске скрипта: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: DropTarget(
          onDragEntered: (_) {
            setState(() => isDragging = true);
          },
          onDragExited: (_) {
            setState(() => isDragging = false);
          },
          onDragDone: (details) {
            setState(() => isDragging = false);
            if (details.files.isNotEmpty) {
              elementPath = details.files.first.path;
              launchPythonScript(elementPath!);
            }
          },
          child: Container(
            height: double.infinity,
            width: double.infinity,
            color: isDragging ? Colors.blue.withOpacity(0.4) : Colors.grey[200],
            child: Center(
              child: Text(
                elementPath != null ? msg : 'Drag a file or folder here',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ),
    );
  }
}




