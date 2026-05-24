import 'package:flutter/material.dart';
import 'package:social_media_app/core/services/supabase_service.dart';
import 'package:social_media_app/core/widgets/user_list_tile.dart';

class UserListScreen extends StatelessWidget {
  final String title;
  final String userId;
  final bool showFollowers;

  const UserListScreen({
    Key? key,
    required this.title,
    required this.userId,
    required this.showFollowers,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _fetchUsers(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }
          final users = snapshot.data ?? [];
          if (users.isEmpty) {
            return Center(child: Text("No users found."));
          }

          return ListView.builder(
            itemCount: users.length,
            itemBuilder: (context, index) => UserListTile(user: users[index]),
          );
        },
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _fetchUsers() async {
    final field = showFollowers ? 'following_id' : 'follower_id';
    final targetField = showFollowers ? 'follower_id' : 'following_id';
    
    final response = await SupabaseService.client
        .from('follows')
        .select('profiles!$targetField(*)')
        .eq(field, userId);
    
    return List<Map<String, dynamic>>.from(response.map((e) => e['profiles']));
  }
}
