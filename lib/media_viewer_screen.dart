import 'dart:io';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:gallery/design_colors.dart';
import 'package:gallery/media_actions_bar.dart';
import 'package:gallery/video_page.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:share_plus/share_plus.dart';

class MediaViewerScreen extends StatefulWidget {
  final ValueNotifier<List<AssetEntity>> assetsNotifier;
  final int initialIndex;

  const MediaViewerScreen({
    super.key,
    required this.assetsNotifier,
    required this.initialIndex,
  });

  @override
  State<MediaViewerScreen> createState() => _MediaViewerScreenState();
}

class _MediaViewerScreenState extends State<MediaViewerScreen> {
  late PageController _pageController;
  late int _currentIndex;
  bool _showUi = true;

  List<AssetEntity> get assets => widget.assetsNotifier.value;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);

    widget.assetsNotifier.addListener(_onAssetsChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _precacheNearbyImages();
    });
  }
  
  void _onAssetsChanged(){
    if(!mounted) return;
    final newAssets = widget.assetsNotifier.value;
    
    if(newAssets.isEmpty){
      Navigator.of(context).pop();
      return;
    }
    
    if(_currentIndex >= newAssets.length){
      _currentIndex = newAssets.length - 1;_pageController.jumpToPage(_currentIndex);
    }
    setState(() {
      
    });
  }

  void _toggleUi() {
    setState(() {
      _showUi = !_showUi;
    });
  }

  void _precacheNearbyImages() {
    for (int i = _currentIndex - 1; i <= _currentIndex + 1; i++) {
      if (i >= 0 && i < assets.length) {
        final asset = assets[i];
        if (asset.type == AssetType.image) {
          asset.file.then((file) {
            if (file != null && mounted) {
              precacheImage(FileImage(file), context);
            }
          });
        }
      }
    }
  }

  String _formatDate(DateTime d) {
    const months = [
      'Января',
      'Февраля',
      'Марта',
      'Апреля',
      'Мая',
      'Июня',
      'Июля',
      'Августа',
      'Сентября',
      'Октября',
      'Ноября',
      'Декабря',
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  String _formatTime(DateTime d) {
    final hour = d.hour.toString().padLeft(2, '0');
    final minute = d.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  Future<void> _shareAsset(AssetEntity asset) async{
    final file = await asset.file;
    if(file != null){
      await Share.shareXFiles([XFile(file.path)]);
    }
  }
  
  Future<void> _toggleFavorite(AssetEntity asset) async{
    try{
      await PhotoManager.editor.darwin.favoriteAsset(
          entity: asset, 
          favorite: !asset.isFavorite,
      );
      setState(() {
        
      });
    }catch(e){
      if(mounted){
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Избранное недоступно на этом устройстве'),
            )
        );
      }
    }
  }
  
  Future<void> _deleteAsset(AssetEntity asset) async{
    final confirmed = await showDialog<bool>(
        context: context, 
        builder: (context) => AlertDialog(
          title: const Text('Удалить?'),
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

    final deleted = await PhotoManager.editor.deleteWithIds([asset.id]);
    if(deleted.isNotEmpty && mounted){
      final newList = [...assets]..removeWhere((a) => a.id == asset.id);
      widget.assetsNotifier.value = newList;
      
      if(newList.isEmpty){
        Navigator.of(context).pop();
      }else if(_currentIndex >= newList.length){
        _currentIndex = newList.length - 1;
        _pageController.jumpToPage(_currentIndex);
      }
    }
  }

  void _showMoreOptions(AssetEntity asset){
    showModalBottomSheet(
        context: context,
        backgroundColor: DesignColors.primary,
        builder: (context) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.info_outline, color: Colors.white,),
                title: const Text(
                    'Сведения о файле',
                  style: TextStyle(
                    color: Colors.white
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  //TODO: show information
                },
              ),
            ],
          ),
        )
    );
  }

  Widget _buildActionIcon({
    required IconData icon,
    required VoidCallback onTap,
}){
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 6,
            vertical: 4,
          ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 24),
            const SizedBox(height: 4,),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    widget.assetsNotifier.removeListener(_onAssetsChanged);
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if(assets.isEmpty){
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Text('Нет файлов', style:  TextStyle(color: Colors.white),),
        ),
      );
    }

    if(_currentIndex >= assets.length){
      _currentIndex = assets.length - 1;
    }

    final asset = assets[_currentIndex];
    final displayDate = asset.createDateTime;

    return Scaffold(
      backgroundColor: DesignColors.background,
      appBar: _showUi
          ? AppBar(
              backgroundColor: DesignColors.primary,
              iconTheme: const IconThemeData(color: DesignColors.background),
              title: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _formatDate(displayDate),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                        ),
                      ),
                      Text(
                        _formatTime(displayDate),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    '${_currentIndex + 1} / ${assets.length}',
                    style: const TextStyle(color: Colors.white, fontSize: 18),
                  ),
                ],
              ),
            )
          : null,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            dragStartBehavior: DragStartBehavior.down,
            itemCount: assets.length,
            onPageChanged: (index) {
              setState(() => _currentIndex = index);
              _precacheNearbyImages();
            },
            itemBuilder: (context, index) {
              final a = assets[index];
              if (a.type == AssetType.video) {
                return VideoPage(asset: a, onToggleUi: _toggleUi);
              }
              return _ImagePage(asset: a, onToggleUi: _toggleUi);
            },
          ),
          if (_showUi)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                top: false,
                bottom: true,
                child: MediaActionsBar(
                    assets: [asset],
                    onShare: () => _shareAsset(asset),
                    onEdit: (){/*TODO*/},
                    onFavorite: () => _toggleFavorite(asset),
                    onDelete: () => _deleteAsset(asset),
                    onMore: () => _showMoreOptions(asset),
                )
              ),
            ),
        ],
      ),
    );
  }
}

class _ImagePage extends StatefulWidget {
  final AssetEntity asset;
  final VoidCallback onToggleUi;

  const _ImagePage({required this.asset, required this.onToggleUi});

  @override
  State<_ImagePage> createState() => _ImagePageState();
}

class _ImagePageState extends State<_ImagePage> {
  File? _file;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    widget.asset.file.then((file) {
      if (mounted) {
        setState(() {
          _file = file;
          _isLoading = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_file == null) {
      return const Center(
        child: Text('Ошибка загрузки', style: TextStyle(color: Colors.white)),
      );
    }
    return GestureDetector(
      onTap: widget.onToggleUi,
      child: InteractiveViewer(
        minScale: 1.0,
        maxScale: 5.0,
        panEnabled: false,
        child: Image.file(_file!, fit: BoxFit.contain, gaplessPlayback: true),
      ),
    );
  }
}
