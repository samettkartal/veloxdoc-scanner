import 'package:hive/hive.dart';
import 'document_model.dart';

class FolderModel extends HiveObject {
  final String id;
  final String name;
  final int colorValue;
  final List<DocumentModel> documents;
  final bool isSecure; // Güvenli klasör mü?

  FolderModel({
    required this.id,
    required this.name,
    required this.colorValue,
    required this.documents,
    this.isSecure = false,
  });

  static void registerAdapter() {
    Hive.registerAdapter(FolderModelAdapter());
  }
}

class FolderModelAdapter extends TypeAdapter<FolderModel> {
  @override
  final int typeId = 1;

  @override
  FolderModel read(BinaryReader reader) {
    return FolderModel(
      id: reader.readString(),
      name: reader.readString(),
      colorValue: reader.readInt(),
      documents: (reader.readList()).cast<DocumentModel>(),
      isSecure: reader.readBool(),
    );
  }

  @override
  void write(BinaryWriter writer, FolderModel obj) {
    writer.writeString(obj.id);
    writer.writeString(obj.name);
    writer.writeInt(obj.colorValue);
    writer.writeList(obj.documents);
    writer.writeBool(obj.isSecure);
  }
}
