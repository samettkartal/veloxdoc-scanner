import 'package:hive/hive.dart';

class DocumentModel {
  final String id;
  final String path;
  final DateTime date;
  final String title;

  DocumentModel({
    required this.id,
    required this.path,
    required this.date,
    required this.title,
  });

  // Hive Adapter Logic (Manual)
  static void registerAdapter() {
    Hive.registerAdapter(DocumentModelAdapter());
  }
}

class DocumentModelAdapter extends TypeAdapter<DocumentModel> {
  @override
  final int typeId = 0;

  @override
  DocumentModel read(BinaryReader reader) {
    return DocumentModel(
      id: reader.readString(),
      path: reader.readString(),
      date: DateTime.fromMillisecondsSinceEpoch(reader.readInt()),
      title: reader.readString(),
    );
  }

  @override
  void write(BinaryWriter writer, DocumentModel obj) {
    writer.writeString(obj.id);
    writer.writeString(obj.path);
    writer.writeInt(obj.date.millisecondsSinceEpoch);
    writer.writeString(obj.title);
  }
}
