import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:gallery/design_colors.dart';
import 'package:gallery/folders.dart';
import 'package:gallery/folder_screen.dart';
import 'package:gallery/album.dart';
import 'package:photo_manager/photo_manager.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final ValueNotifier<List<Album>> albumsNotifier = ValueNotifier<List<Album>>(
    [],
  );
  bool isLoading = true;

  Future<void> createAlbum({String? parentId}) async {
    final TextEditingController controller = TextEditingController();

    final String? name = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Новая папка"),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'Имя папки'),
            onSubmitted: (value) => Navigator.of(context).pop(value),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("Отмена"),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(controller.text),
              child: const Text("Создать"),
            ),
          ],
        );
      },
    );

    if (name == null) return;

    final String trimmed = name.trim();
    if (trimmed.isEmpty) return;

    final Album newAlbum = Album(
      DateTime.now().microsecondsSinceEpoch.toString(),
      trimmed,
      0,
      null,
      parentId: parentId,
    );

    albumsNotifier.value = [...albumsNotifier.value, newAlbum];
  }

  void openFolder(Album album) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FolderScreen(
          album: album,
          albumsNotifier: albumsNotifier,
          onAddSubfolder: (parent) async {
            await createAlbum(parentId: parent.id);
          },
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    loadAlbums();
  }

  Future<void> loadAlbums() async {
    final PermissionState ps = await PhotoManager.requestPermissionExtend();
    if (!ps.isAuth) {
      setState(() => isLoading = false);
      return;
    }

    final List<AssetPathEntity> paths = await PhotoManager.getAssetPathList(
      type: RequestType.common,
      onlyAll: false,
      filterOption: FilterOptionGroup(
        orders: [OrderOption(type: OrderOptionType.createDate, asc: false)],
      ),
    );

    final List<Album> loaded = [];
    for (final path in paths) {
      final int count = await path.assetCountAsync;

      final List<AssetEntity> preview = await path.getAssetListPaged(
        page: 0,
        size: 1,
      );

      final Uint8List? cover = preview.isNotEmpty
          ? await preview.first.thumbnailDataWithSize(
              const ThumbnailSize(200, 200),
            )
          : null;

      loaded.add(Album(path.id, path.name, count, cover));
    }

    albumsNotifier.value = loaded;
    setState(() => isLoading = false);
  }

  @override
  void dispose() {
    albumsNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Галерея", style: TextStyle(fontSize: 26)),
        backgroundColor: DesignColors.primary,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : ValueListenableBuilder<List<Album>>(
              valueListenable: albumsNotifier,
              builder: (context, allAlbums, _) {
                final rootAlbums = allAlbums
                    .where((a) => a.parentId == null)
                    .toList();
                return GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 0.56,
                  ),
                  itemCount: rootAlbums.length,
                  itemBuilder: (context, i) => Folders(
                    album: rootAlbums[i],
                    onTap: () => openFolder(rootAlbums[i]),
                  ),
                );
              },
            ),
      backgroundColor: DesignColors.background,
      floatingActionButton: FloatingActionButton(
        onPressed: () => createAlbum(parentId: null),
        backgroundColor: DesignColors.button,
        child: const Icon(Icons.add),
      ),
    );
  }
}
