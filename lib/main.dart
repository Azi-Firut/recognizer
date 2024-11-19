import 'dart:async';
import 'dart:io';
import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:path/path.dart' as path;
import 'package:flutter/services.dart' show rootBundle;
import 'package:desktop_drop/desktop_drop.dart';

void main() {
  appWindow.size = const Size(350, 260);
  runApp(DiagnosticsSuiteDnD());
  appWindow.hide();
  doWhenWindowReady(() {
    final win = appWindow;
    const initialSize = Size(350, 260);
    win.minSize = initialSize;
    win.size = initialSize;
    win.alignment = Alignment.topRight;
    win.title = "Diagnostics Suite";
    win.show();
  });
}

const borderColor = Color(0x1800A4FC);

class DiagnosticsSuiteDnD extends StatelessWidget {
  DiagnosticsSuiteDnD({super.key});

  @override
  Widget build(BuildContext context) {
    return  MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: WindowBorder(
            color: borderColor,
            width: 0,
            child: const Row(
              children: [RightSide()],
            ),
          ),
        ),
      );
    }
}


const backgroundStartColor = Color(0xFF020E22);
const backgroundStartColor2 = Color(0xFF010917);
const backgroundEndColor = Color(0xFF211002);

class RightSide extends StatefulWidget {
  const RightSide({Key? key}) : super(key: key);

  @override
  _RightSideState createState() => _RightSideState();
}

class _RightSideState extends State<RightSide> {

  String? elementPath;
  bool isDragging = false;
  Map<String, String>? scriptMapping;
  String msg="";

  @override
  void initState() {
    super.initState();
    _loadScriptMapping();
  }

  void updateState() {
    setState(() {});
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
      updateState();
    }
  }

  void launchPythonScript(String elementPath) async {
    if (scriptMapping == null) {
      msg='Script mapping is not loaded.';
      print('Маппинг скриптов не загружен.');
      updateState();
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
        updateState();
        return;
      }
    } else if (entity is Directory) {
      scriptName = scriptMapping!["directory"];
      if (scriptName == null) {
        msg='The script for the folders is not specified.';
        print('Скрипт для папок не указан.');
        updateState();
        return;
      }
    } else {
      msg='Unknown element type: $elementPath';
      print('Неизвестный тип элемента: $elementPath');
      updateState();
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
        updateState();
      } else {
        msg='Error: $error\nTry to install Python.';
        print('Ошибка: $error');
        updateState();
        try {
          String installerPath = path.join(Directory.current.path, 'assets', 'python-3.13.0-amd64.exe');
          await Process.start(installerPath, [], runInShell: false);
         // msg = 'Python installer started.';
          print('Установщик Python запущен.');
        } catch (installError) {
          msg = 'Failed to start Python installer: $installError';
          print('Не удалось запустить установщик Python: $installError');
        }
      }

      await process.stdin.close();
    } catch (e) {
      msg='Error when running the script: $e\nTry to install Python';
      print('Ошибка при запуске скрипта: $e');
      updateState();
      try {
        String installerPath = path.join(Directory.current.path, 'assets', 'python-3.13.0-amd64.exe');
        await Process.start(installerPath, [], runInShell: false);
        msg = 'Try to install Python.';
        print('Установщик Python запущен.');
      } catch (installError) {
        msg = 'Failed to start Python installer: $installError';
        print('Не удалось запустить установщик Python: $installError');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              backgroundStartColor,
              backgroundStartColor2,
              backgroundEndColor,
            ],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: Column(
          children: [
            WindowTitleBarBox(
              child: Row(
                children: [
                  const Text(
                    "   RES",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFFFFFFF),
                    ),
                  ),
                  const Text(
                    "EPI",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFEF6705),
                    ),
                  ),
                  const Text(
                    " Diagnostics Suite",
                    style: TextStyle(
                     // fontWeight: FontWeight.bold,
                      color: Color(0xFFC0C0C0),
                    ),
                  ),
                  Expanded(child: MoveWindow()),
                  WindowButtons(),
                ],
              ),
            ),
            Expanded(
              child: Center(
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
                  //  color: isDragging ? Colors.blue.withOpacity(0.4) : Colors.grey[200],
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(22.0),
                        child: Text(
                          elementPath != null ? msg : 'Drag a file or folder here',
                          textAlign: TextAlign.center,
                           style: const TextStyle(
                             color: Color(0xFF777777),
                        ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

final buttonColors = WindowButtonColors(
  iconNormal: const Color(0xFF777777),
  mouseOver: const Color(0x8005455D),
  mouseDown: const Color(0x80097EAB),
  iconMouseOver: const Color(0xFFFFFEFE),
  iconMouseDown: const Color(0xFF777777),
);

final closeButtonColors = WindowButtonColors(
  mouseOver: const Color(0xFFEF6705),
  mouseDown: const Color(0xFFB71C1C),
  iconNormal: const Color(0xFF777777),
  iconMouseOver: Colors.white,
);

class WindowButtons extends StatefulWidget {
  const WindowButtons({super.key});

  @override
  State<WindowButtons> createState() => _WindowButtonsState();
}

class _WindowButtonsState extends State<WindowButtons> {
  void maximizeOrRestore() {
    setState(() {
      appWindow.maximizeOrRestore();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [

        SizedBox(width:33,child: MinimizeWindowButton(colors: buttonColors)),
        appWindow.isMaximized
            ? SizedBox(width:33,
              child: RestoreWindowButton(
                        colors: buttonColors,
                        onPressed: maximizeOrRestore,
                      ),
            )
            : SizedBox(width:33,
              child: MaximizeWindowButton(
                        colors: buttonColors,
                        onPressed: maximizeOrRestore,
                      ),
            ),
        SizedBox(width:33,child: CloseWindowButton(colors: closeButtonColors)),
      ],
    );
  }
}
