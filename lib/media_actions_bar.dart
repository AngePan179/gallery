import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:gallery/design_colors.dart';
import 'package:photo_manager/photo_manager.dart';

class MediaActionsBar extends StatelessWidget{
  final List<AssetEntity> assets;
  final VoidCallback onShare;
  final VoidCallback onEdit;
  final VoidCallback onFavorite;
  final VoidCallback onDelete;
  final VoidCallback onMore;

  const MediaActionsBar({
    super.key,
    required this.assets,
    required this.onShare,
    required this.onEdit,
    required this.onFavorite,
    required this.onDelete,
    required this.onMore
  });

  @override
  Widget build(BuildContext context){
    final showEdit = assets.length == 1 && assets.first.type == AssetType.image;
    final allFavorite = assets.isNotEmpty && assets.every((a) => a.isFavorite);

    return SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          color: DesignColors.primary,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildActionIcon(
                icon: Icons.share,
                onTap: onShare
              ),
              if(showEdit)
                _buildActionIcon(
                    icon: Icons.edit,
                    onTap: onEdit
                ),
              _buildActionIcon(
                  icon: allFavorite ? Icons.favorite : Icons.favorite_border,
                  onTap: onFavorite,
              ),
              _buildActionIcon(
                  icon: Icons.delete,
                  onTap: onDelete
              ),
              _buildActionIcon(
                  icon: Icons.more_horiz,
                  onTap: onMore,
              ),
            ],
          ),
        )
    );
  }

  Widget _buildActionIcon({required IconData icon, required VoidCallback onTap}){
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 6,
            vertical: 4
          ),
        child: Icon(icon, color: Colors.white, size: 24,),
      ),
    );
  }
}