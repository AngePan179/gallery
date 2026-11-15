import 'package:flutter/material.dart';
import 'package:gallery/album.dart';

class Folders extends StatelessWidget {
  final Album album;
  final VoidCallback? onTap;

  const Folders({super.key, required this.album, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: album.cover != null
                  ? Image.memory(album.cover!, fit: BoxFit.cover)
                  : Container(color: Colors.grey.shade400),
            ),
          ),
          const SizedBox(height: 4),
          Text(album.name, maxLines: 2, overflow: TextOverflow.ellipsis),
          Text(album.count.toString()),
        ],
      ),
    );
  }
}
