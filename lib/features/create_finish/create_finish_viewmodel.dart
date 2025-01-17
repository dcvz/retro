import 'dart:collection';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_storm/bridge/errors.dart';
import 'package:flutter_storm/flutter_storm.dart';
import 'package:flutter_storm/bridge/flags.dart';
import 'package:retro/otr/types/sequence.dart';
import 'package:retro/models/app_state.dart';
import 'package:retro/models/stage_entry.dart';
import 'package:tuple/tuple.dart';

class CreateFinishViewModel with ChangeNotifier {
  AppState currentState = AppState.none;
  HashMap<String, StageEntry> entries = HashMap();
  late BuildContext context;
  bool isEphemeralBarExpanded = false;
  bool isGenerating = false;

  void bindGlobalContext(BuildContext ctx) {
    context = ctx;
  }

  String displayState() {
    bool hasStagedFiles = entries.isNotEmpty;
    return "${currentState.name}${hasStagedFiles && currentState != AppState.changesStaged ? ' (staged)' : ''}";
  }

  void toggleEphemeralBar() {
    isEphemeralBarExpanded = !isEphemeralBarExpanded;
    notifyListeners();
  }

  void resetState() {
    currentState = AppState.none;
    entries.clear();
    notifyListeners();
  }

  // Stage Management
  void onAddCustomStageEntry(List<File> files, String path) {
    if (entries.containsKey(path) && entries[path] is CustomStageEntry) {
      (entries[path] as CustomStageEntry).files.addAll(files);
    } else if (entries.containsKey(path)) {
      throw Exception("Cannot add custom stage entry to existing entry");
    } else {
      entries[path] = CustomStageEntry(files);
    }

    currentState = AppState.changesStaged;
    notifyListeners();
  }

  void onAddCustomSequenceEntry(List<Tuple2<File, File>> pairs, String path) {
    if (entries.containsKey(path) && entries[path] is CustomSequencesEntry) {
      (entries[path] as CustomSequencesEntry).pairs.addAll(pairs);
    } else if (entries.containsKey(path)) {
      throw Exception("Cannot add custom sequence entry to existing entry");
    } else {
      entries[path] = CustomSequencesEntry(pairs);
    }

    currentState = AppState.changesStaged;
    notifyListeners();
  }

  void onRemoveFile(File file, String path) {
    if (entries.containsKey(path) && entries[path] is CustomStageEntry) {
      (entries[path] as CustomStageEntry).files.remove(file);
    } else if (entries.containsKey(path) &&
        entries[path] is CustomSequencesEntry) {
      (entries[path] as CustomSequencesEntry).pairs.removeWhere((pair) =>
          pair.item1.path == file.path || pair.item2.path == file.path);
    } else {
      throw Exception("Cannot remove file from non-existent entry");
    }

    if (entries[path]?.iterables.isEmpty == true) {
      entries.remove(path);
    }

    if (entries.isEmpty) {
      currentState = AppState.none;
    }

    notifyListeners();
  }

  void onGenerateOTR(Function onCompletion) async {
    String? outputFile = await FilePicker.platform.saveFile(
      dialogTitle: 'Please select an output file:',
      fileName: 'generated.otr',
    );

    if (outputFile == null) {
      return;
    }

    File mpqOut = File(outputFile);
    if (mpqOut.existsSync()) {
      mpqOut.deleteSync();
    }

    try {
      String? mpqHandle = await SFileCreateArchive(outputFile, MPQ_CREATE_SIGNATURE | MPQ_CREATE_ARCHIVE_V4, 1024);

      isGenerating = true;
      notifyListeners();

      for (var entry in entries.entries) {
        if (entry.value is CustomStageEntry) {
          for (var file in (entry.value as CustomStageEntry).files) {
            String fileName = "${entry.key}/${file.path.split('/').last}";
            String? fileHandle = await SFileCreateFile(
                mpqHandle!, fileName, file.lengthSync(), MPQ_FILE_COMPRESS);
            await SFileWriteFile(fileHandle!, file.readAsBytesSync(),
                file.lengthSync(), MPQ_COMPRESSION_ZLIB);
            await SFileFinishFile(fileHandle);
          }
        } else if (entry.value is CustomSequencesEntry) {
          for (var pair in (entry.value as CustomSequencesEntry).pairs) {
            Sequence sequence = Sequence.fromSeqFile(pair);
            String fileName = "${entry.key}/${sequence.path}";
            Uint8List data = sequence.build();

            String? fileHandle = await SFileCreateFile(
                mpqHandle!, fileName, data.length, MPQ_FILE_COMPRESS);
            await SFileWriteFile(
                fileHandle!, data, data.length, MPQ_COMPRESSION_ZLIB);
            await SFileFinishFile(fileHandle);
          }
        }
      }

      await SFileCloseArchive(mpqHandle!);
      isGenerating = false;
      notifyListeners();

      resetState();
      onCompletion();
    } on StormException catch (e) {
      print(e);
    }
  }
}
