import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  final ValueNotifier<List<Album>> systemAlbumsNotifier = ValueNotifier<List<Album>>([]);
  final ValueNotifier<List<Album>> userAlbumsNotifier = ValueNotifier<List<Album>>([]);
  bool isLoading = true;
  Timer? _debounce;

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
      firstAssetId: null,
    );

    userAlbumsNotifier.value = [...userAlbumsNotifier.value, newAlbum];
  }

  void openFolder(Album album) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FolderScreen(
          album: album,
          systemAlbumsNotifier: systemAlbumsNotifier,
          userAlbumsNotifier: userAlbumsNotifier,
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
    PhotoManager.addChangeCallback(_onMediaChanged);
    PhotoManager.startChangeNotify();
  }

  void _onMediaChanged(MethodCall call) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      loadAlbums();
    });
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

    final oldAlbums = systemAlbumsNotifier.value;
    final List<Album> loaded = [];

    for (final path in paths) {
      final int count = await path.assetCountAsync;

      final List<AssetEntity> preview = await path.getAssetListPaged(
        page: 0,
        size: 1,
      );

      final String? firstAssetId = preview.isNotEmpty ? preview.first.id : null;

      final oldAlbum = oldAlbums.firstWhere(
          (a) => a.id == path.id,
        orElse: () => Album('', '', -1, null),
      );

      if(oldAlbum.count == count && oldAlbum.firstAssetId == firstAssetId){
        loaded.add(oldAlbum);
        continue;
      }

      final Uint8List? cover = preview.isNotEmpty
          ? await preview.first.thumbnailDataWithSize(
        const ThumbnailSize(200, 200),
      )
          : null;

      loaded.add(Album(path.id, path.name, count, cover, firstAssetId: firstAssetId));
    }

    systemAlbumsNotifier.value = loaded;
    setState(() => isLoading = false);
  }

  @override
  void dispose() {
    PhotoManager.removeChangeCallback(_onMediaChanged);
    _debounce?.cancel();
    systemAlbumsNotifier.dispose();
    userAlbumsNotifier.dispose();
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
        valueListenable: systemAlbumsNotifier,
        builder: (context, systemAlbums, _) {
          return ValueListenableBuilder<List<Album>>(
            valueListenable: userAlbumsNotifier,
            builder: (context, userAlbums, _) {
              final allAlbums = [...systemAlbums, ...userAlbums];
              final rootAlbums = allAlbums
                  .where((a) => a.parentId == null)
                  .toList();
              return RefreshIndicator(
                onRefresh: () async {
                  await loadAlbums();
                },
                child: GridView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(12),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 0.56,
                  ),
                  itemCount: rootAlbums.length,
                  itemBuilder: (context, i) => Folders(
                    key: ValueKey(rootAlbums[i].id),
                    album: rootAlbums[i],
                    onTap: () => openFolder(rootAlbums[i]),
                  ),
                ),
              );
            },
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