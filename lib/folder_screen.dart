import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gallery/album.dart';
import 'package:gallery/design_colors.dart';
import 'package:gallery/folders.dart';
import 'package:gallery/media_actions_bar.dart';
import 'package:gallery/media_viewer_screen.dart';
import 'package:gallery/photo_title.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:share_plus/share_plus.dart';

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
  AssetPathEntity? _path;
  bool _isSelectionMode = false;
  final Set<String> _selectedIds = {};

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

  void _toggleSelection(AssetEntity asset){
    setState(() {
      if(!_isSelectionMode){
        _isSelectionMode = true;
        _selectedIds.add(asset.id);
      }else{
        if(_selectedIds.contains((asset.id))){
          _selectedIds.remove(asset.id);
          if(_selectedIds.isEmpty) _isSelectionMode = false;
        }else{
          _selectedIds.add(asset.id);
        }
      }
    });
  }

  void _exitSelectionMode(){
    setState(() {
      _isSelectionMode = false;
      _selectedIds.clear();
    });
  }
  
  Future<void> _deleteSelected() async{
    if(_selectedIds.isEmpty) return;
    
    final confirmed = await showDialog<bool>(
        context: context, 
        builder: (context) => AlertDialog(
          title: Text('Удалить ${_selectedIds.length} файлов?'),
          content: const Text('Это действие нельзя отменить.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Отмена'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Удалить'),
            ),
          ],
        )
    );

    if(confirmed != true) return;

    final ids = _selectedIds.toList();
    final deleted = await PhotoManager.editor.deleteWithIds(ids);

    if(deleted.isNotEmpty && mounted){
      await loadAssets(
          silent: true
      );
      _exitSelectionMode();
    }
  }

  Future<void> _shareSelected() async{
    final files = <XFile>[];
    for(final id in _selectedIds){
      final asset = assets.firstWhere((a) => a.id == id);
      final file = await asset.file;
      if(file != null) files.add(XFile(file.path));
    }
    if(files.isNotEmpty){
      await Share.shareXFiles(files);
    }
  }

  void _editSelected(){
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Редактирование пока не реализовано'),
      )
    );
  }
  
  Future<void> _toggleFavoriteSelected() async{
    for(final id in _selectedIds){
      final asset = assets.firstWhere((a) => a.id == id);
      try{
        await PhotoManager.editor.darwin.favoriteAsset(
            entity: asset, 
            favorite: !asset.isFavorite,
        );
      }catch(_){
    }
      if(mounted){
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Избранное недоступно на этом устройстве'))
        );
      }
}
  }
  
  void _showMoreOptionsSelected(){
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Доп. настройки пока не реализованы'))
    );
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
    final paths = await PhotoManager.getAssetPathList(
      type: RequestType.common,
      onlyAll: false,
      filterOption: FilterOptionGroup(
        orders: [
          OrderOption(
            type: OrderOptionType.createDate,
            asc: false,
          )
        ]
      ),
    );
    _path = paths
      .cast<AssetPathEntity?>()
      .firstWhere((p) => p?.id == widget.album.id, orElse: () => null);

    if(_path == null){
      if(mounted) setState(() => isLoading = false);
      return;
    }

    final int total = await _path!.assetCountAsync;
    final List<AssetEntity> loaded = total == 0
      ? []
    : await _path!.getAssetListRange(start: 0, end: total);

    if(!mounted) return;

    final bool isSame =
      loaded.length == assets.length &&
          List.generate(loaded.length, (i) => loaded[i].id == assets[i].id)
            .every((e) => e);

    if(!isSame) {
      assetsNotifier.value = loaded;
    }

    if(!silent) setState(() => isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isSelectionMode,
        onPopInvokedWithResult: (dipPop, _){
          if(!dipPop) _exitSelectionMode();
        },
        child: Scaffold(
          backgroundColor: DesignColors.background,
          appBar: AppBar(
            backgroundColor: DesignColors.primary,
            leading: _isSelectionMode
                ? IconButton(
                onPressed: _exitSelectionMode,
                icon: const Icon(Icons.close, color: Colors.white,)
            )
                : null,
            title: const Text("Галерея", style: TextStyle(fontSize: 26)),
            actions: _isSelectionMode
                ? [
                  Center(
                    child: Padding(
                        padding: const EdgeInsets.only(
                          right: 16,
                        ),
                      child: Text(
                        '${_selectedIds.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18
                        ),
                      ),
                    ),
                  )
            ]
              : null
          ),
          bottomNavigationBar: _isSelectionMode
            ? MediaActionsBar(
              assets: _selectedIds
                .map((id) => assets.firstWhere((a) => a.id == id))
                .toList(),
              onShare: _shareSelected,
              onEdit: _editSelected,
              onFavorite: _toggleFavoriteSelected,
              onDelete: _deleteSelected,
              onMore: _showMoreOptionsSelected,
          )
          : null,
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
        )
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
            final asset = assets[assetIndex];
            final isSelected = _selectedIds.contains(asset.id);

            return GestureDetector(
              onTap: (){
                if(_isSelectionMode){
                  _toggleSelection(asset);
                }else{
                  _openViewer(assetIndex);
                }
              },
              onLongPress: (){
                if(!_isSelectionMode){
                  _toggleSelection(asset);
                }
              },
              child: Stack(
                fit: StackFit.expand,
                children: [
                  PhotoTitle(
                    key: ValueKey(asset.id),
                      asset: asset,
                  ),
                  if(isSelected)
                    Positioned(
                      top: 4,
                        right: 4,
                        child: Container(
                          decoration: BoxDecoration(
                            color: DesignColors.primary,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white,
                              width: 2,
                            )
                          ),
                      padding: const EdgeInsets.all(2),
                      child: const Icon(
                        Icons.check,
                      color: Colors.white,
            size: 16,
                      ),
                        )
                    )
                ],
              ),
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
