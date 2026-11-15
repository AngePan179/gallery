import 'package:flutter/material.dart';
import 'package:gallery/album.dart';
import 'package:gallery/design_colors.dart';
import 'package:gallery/folders.dart';
import 'package:gallery/media_viewer_screen.dart';
import 'package:gallery/photo_title.dart';
import 'package:photo_manager/photo_manager.dart';

class FolderScreen extends StatefulWidget {
  final Album album;
  final ValueNotifier<List<Album>> albumsNotifier; // ← вместо List
  final void Function(Album parent) onAddSubfolder;

  const FolderScreen({
    super.key,
    required this.album,
    required this.albumsNotifier,
    required this.onAddSubfolder,
  });

  @override
  State<FolderScreen> createState() => _FolderScreenState();
}

class _FolderScreenState extends State<FolderScreen> {
  List<AssetEntity> assets = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadAssets();
  }

  Future<void> loadAssets() async {
    final AssetPathEntity? path = await AssetPathEntity.fromId(widget.album.id);

    if (path == null) {
      setState(() => isLoading = false);
      return;
    }

    final int total = await path.assetCountAsync;
    final List<AssetEntity> loaded = total == 0
        ? []
        : await path.getAssetListPaged(page: 0, size: total);

    setState(() {
      assets = loaded;
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<Album>>(
      valueListenable: widget.albumsNotifier,
      builder: (context, allAlbums, _) {
        final subs = allAlbums
            .where((a) => a.parentId == widget.album.id)
            .toList();

        return Scaffold(
          backgroundColor: DesignColors.background,
          appBar: AppBar(
            title: const Text("Галерея", style: TextStyle(fontSize: 26)),
            backgroundColor: DesignColors.primary,
          ),
          body: Column(
            children: [
              _buildSecondaryAppBar(),
              Expanded(child: _buildContent(subs)),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () => widget.onAddSubfolder(widget.album),
            backgroundColor: DesignColors.button,
            child: const Icon(Icons.add),
          ),
        );
      },
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
      return const Center(child: Text('Здесь пока ничего нет'));
    }

    return GridView.builder(
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
    );
  }

  void _openSubfolder(Album sub) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FolderScreen(
          album: sub,
          albumsNotifier: widget.albumsNotifier, // ← тот же notifier
          onAddSubfolder: widget.onAddSubfolder,
        ),
      ),
    );
  }

  void _openViewer(int index) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MediaViewerScreen(assets: assets, initialIndex: index),
      ),
    );
  }
}
