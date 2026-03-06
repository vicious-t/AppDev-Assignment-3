import 'package:flutter/material.dart';

class FullscreenImagePage extends StatelessWidget {
  final ImageProvider image;
  final String heroTag;

  const FullscreenImagePage({
    super.key,
    required this.image,
    required this.heroTag,
  });

  static Future<void> open(
      BuildContext context, {
        required ImageProvider image,
        required String heroTag,
      }) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FullscreenImagePage(image: image, heroTag: heroTag),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Hero(
          tag: heroTag,
          child: InteractiveViewer(
            minScale: 1,
            maxScale: 5,
            child: Image(
              image: image,
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }
}