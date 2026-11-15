import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

class PhotoTitle extends StatefulWidget {
  final AssetEntity asset;

  const PhotoTitle({super.key, required this.asset});

  @override
  State<PhotoTitle> createState() => _PhotoTileState();
}

class _PhotoTileState extends State<PhotoTitle> {
  Uint8List? thumb;

  @override
  void initState() {
    super.initState();
    widget.asset.thumbnailDataWithSize(const ThumbnailSize(200, 200)).then((
      data,
    ) {
      if (mounted) setState(() => thumb = data);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.grey.shade300,
      child: thumb != null
          ? Image.memory(thumb!, fit: BoxFit.cover)
          : const SizedBox.shrink(),
    );
  }
}
