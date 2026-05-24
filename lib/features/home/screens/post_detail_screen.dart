import 'package:flutter/material.dart';
import 'package:social_media_app/features/home/widgets/post_card.dart';

class PostDetailScreen extends StatelessWidget {
  final Map<String, dynamic> postData;
  final String? heroTag;
  final bool autoOpenComments;
  const PostDetailScreen({Key? key, required this.postData, this.heroTag, this.autoOpenComments = false}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Post"),
      ),
      body: SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: PostCard(postData: postData, heroTag: heroTag, autoOpenComments: autoOpenComments),
          ),
        ),
      ),
    );
  }
}
