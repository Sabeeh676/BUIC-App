import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'full_screen_viewer.dart';

class ImageGrid extends StatelessWidget {
  final List<String> imageUrls;
  const ImageGrid({super.key, required this.imageUrls});

  void _openFullScreenViewer(BuildContext context, final int index) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FullScreenImageViewer(
          imageUrls: imageUrls,
          initialIndex: index,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (imageUrls.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: GestureDetector(
        onTap: () => _openFullScreenViewer(context, 0),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12.0),
          child: Container(
            height: 250,
            color: Colors.grey[200],
            child: _buildGrid(context),
          ),
        ),
      ),
    );
  }

  Widget _buildGrid(BuildContext context) {
    switch (imageUrls.length) {
      case 1:
        return _buildImage(context, imageUrls[0], 0, fit: BoxFit.cover);
      case 2:
        return Row(
          children: [
            Expanded(child: _buildImage(context, imageUrls[0], 0)),
            const SizedBox(width: 2),
            Expanded(child: _buildImage(context, imageUrls[1], 1)),
          ],
        );
      case 3:
        return Row(
          children: [
            Expanded(child: _buildImage(context, imageUrls[0], 0)),
            const SizedBox(width: 2),
            Expanded(
              child: Column(
                children: [
                  Expanded(child: _buildImage(context, imageUrls[1], 1)),
                  const SizedBox(height: 2),
                  Expanded(child: _buildImage(context, imageUrls[2], 2)),
                ],
              ),
            ),
          ],
        );
      case 4:
        return Row(
          children: [
            Expanded(child: _buildImage(context, imageUrls[0], 0)),
            const SizedBox(width: 2),
            Expanded(
              child: Column(
                children: [
                  Expanded(child: _buildImage(context, imageUrls[1], 1)),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Expanded(child: _buildImage(context, imageUrls[2], 2)),
                      const SizedBox(width: 2),
                      Expanded(child: _buildImage(context, imageUrls[3], 3)),
                    ],
                  )
                ],
              ),
            ),
          ],
        );
      default: // 5 or more images
        return Row(
          children: [
            Expanded(
              flex: 2,
              child: _buildImage(context, imageUrls[0], 0),
            ),
            const SizedBox(width: 2),
            Expanded(
              flex: 1,
              child: Column(
                children: [
                  Expanded(child: _buildImage(context, imageUrls[1], 1)),
                  const SizedBox(height: 2),
                  Expanded(
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        _buildImage(context, imageUrls[2], 2),
                        Positioned.fill(
                          child: GestureDetector(
                            onTap: () => _openFullScreenViewer(context, 2),
                            child: Container(
                              color: Colors.black.withOpacity(0.5),
                              child: Center(
                                child: Text(
                                  '+${imageUrls.length - 2}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
    }
  }

  Widget _buildImage(BuildContext context, String url, int index,
      {BoxFit fit = BoxFit.cover}) {
    return GestureDetector(
      onTap: () => _openFullScreenViewer(context, index),
      child: CachedNetworkImage(
        imageUrl: url,
        fit: fit,
        placeholder: (context, url) =>
            const Center(child: CircularProgressIndicator()),
        errorWidget: (context, url, error) =>
            const Icon(Icons.error, color: Colors.red),
      ),
    );
  }
}
