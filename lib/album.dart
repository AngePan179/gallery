import 'dart:typed_data';

class Album {
  final String id;
  final String name;
  final int count;
  final Uint8List? cover;
  final String? parentId;

  Album(this.id, this.name, this.count, this.cover, {this.parentId});
}
