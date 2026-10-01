import 'package:flutter/material.dart';

class VideoInitializingWidget extends StatelessWidget {
  const VideoInitializingWidget({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Edit video')),
    body: const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Preparing video…'),
        ],
      ),
    ),
  );
}
