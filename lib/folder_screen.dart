import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gallery/album.dart';
import 'package:gallery/design_colors.dart';
import 'package:gallery/folders.dart';
import 'package:gallery/media_viewer_screen.dart';
import 'package:gallery/photo_title.dart';
import 'package:photo_manager/photo_manager.dart';

class FolderScreen extends StatefulWidget {
  final Album album;
  final ValueNotifier<List<Album>> systemAlbumsNotifier;
  final ValueNotifier<List<Album>> userAlbumsNotifier;
  final void Function(Album parent) onAddSubfolder;

  const FolderScreen({
    super.key,
    required this.album,
    required this.systemAlbumsNotifier,
    required this.userAlbumsNotifier,
    required this.onAddSubfolder,
  });

  @override
  State<FolderScreen> createState() => _FolderScreenState();
}

class _FolderScreenState extends State<FolderScreen> {
  final ValueNotifier<List<AssetEntity>> assetsNotifier =
    ValueNotifier<List<AssetEntity>>([]);
  bool isLoading = true;
  Timer? _debounce;

  List<AssetEntity> get assets => assetsNotifier.value;

  @override
  void initState() {
    super.initState();
    loadAssets();
    PhotoManager.addChangeCallback(_onMediaChanged);
    PhotoManager.startChangeNotify();
  }

  void _onMediaChanged(MethodCall call){
    print('CHANGE: ${call.method}');
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), (){
      loadAssets(silent: true);
    });
  }

  @override
  void dispose(){
    PhotoManager.removeChangeCallback(_onMediaChanged);
    _debounce?.cancel();
    assetsNotifier.dispose();
    super.dispose();
  }

  Future<void> loadAssets({bool silent = false}) async {
    if(!silent) setState(() => isLoading = true);

    await PhotoManager.clearFileCache();

    final List<AssetPathEntity> paths = await PhotoManager.getAssetPathList(
      type: RequestType.common,
      onlyAll: false,
      filterOption: FilterOptionGroup(
        orders: [OrderOption(
          type: OrderOptionType.createDate,
          asc: false,
        )],
      )
    );

    final AssetPathEntity? path = paths
      .cast<AssetPathEntity?>()
      .firstWhere((p) => p?.id == widget.album.id, orElse: () => null);

    if (path == null) {
      if(mounted) setState(() => isLoading = false);
      return;
    }

    final int total = await path.assetCountAsync;

    final List<AssetEntity> loaded = total == 0
        ? []
        : await path.getAssetListRange(start: 0, end: total);

    if(!mounted) return;

    assetsNotifier.value = loaded;
    if(!silent) setState(() => isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DesignColors.background,
      appBar: AppBar(
        title: const Text("Галерея", style: TextStyle(fontSize: 26)),
        backgroundColor: DesignColors.primary,
      ),
      body: Column(
        children: [
          _buildSecondaryAppBar(),
          Expanded(
            child: ValueListenableBuilder<List<Album>>(
              valueListenable: widget.systemAlbumsNotifier,
              builder: (context, systemAlbums, _) {
                return ValueListenableBuilder<List<Album>>(
                  valueListenable: widget.userAlbumsNotifier,
                  builder: (context, userAlbums, _) {
                    final allAlbums = [...systemAlbums, ...userAlbums];
                    final subs = allAlbums
                        .where((a) => a.parentId == widget.album.id)
                        .toList();
                    return _buildContent(subs);
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => widget.onAddSubfolder(widget.album),
        backgroundColor: DesignColors.button,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildSecondaryAppBar() {
    return AppBar(
      backgroundColor: DesignColors.primary.withValues(alpha: 0.85),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: Text(
        widget.album.name,
        style: const TextStyle(
          fontSize: 18,
          color: Colors.white,
          fontWeight: FontWeight.w500,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildContent(List<Album> subs) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (subs.isEmpty && assets.isEmpty) {
      return RefreshIndicator(
          onRefresh: () => loadAssets(silent: true),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: const[
              SizedBox(
                height: 200,
              ),
            Center(
                child: Text('Здесь пока ничего нет')
            ),
            ],
          )
      );
    }

    return RefreshIndicator(
        onRefresh: () => loadAssets(silent: true),
        child: GridView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(12),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 1,
          ),
          itemCount: subs.length + assets.length,
          itemBuilder: (context, i) {
            if (i < subs.length) {
              return Folders(album: subs[i], onTap: () => _openSubfolder(subs[i]));
            }

            final assetIndex = i - subs.length;
            return GestureDetector(
              onTap: () => _openViewer(assetIndex),
              child: PhotoTitle(asset: assets[assetIndex]),
            );
          },
        ),
    );
  }

  void _openSubfolder(Album sub) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FolderScreen(
          album: sub,
          systemAlbumsNotifier: widget.systemAlbumsNotifier,
          userAlbumsNotifier: widget.userAlbumsNotifier,
          onAddSubfolder: widget.onAddSubfolder,
        ),
      ),
    );
  }

  void _openViewer(int index) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MediaViewerScreen(
            assetsNotifier: assetsNotifier,
            initialIndex: index
        ),
      ),
    );
  }
}
