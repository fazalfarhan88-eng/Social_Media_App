import 'dart:async';
import 'package:flutter/material.dart';
import 'package:social_media_app/core/services/supabase_service.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:iconsax/iconsax.dart';
import 'package:social_media_app/core/widgets/user_list_tile.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({Key? key}) : super(key: key);

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _userResults = [];
  List<Map<String, dynamic>> _postResults = [];
  String _selectedTag = "For You";
  Timer? _debounce;

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      if (query.isEmpty) {
        if (mounted) {
          setState(() {
            _userResults = [];
            _postResults = [];
          });
        }
        return;
      }


      
      try {
        final users = await SupabaseService.client
            .from('profiles')
            .select()
            .or('username.ilike.%$query%,full_name.ilike.%$query%')
            .limit(10);

        final posts = await SupabaseService.client
            .from('posts_with_profiles')
            .select()
            .ilike('caption', '%$query%')
            .limit(10);

        if (mounted) {
          setState(() {
            _userResults = List<Map<String, dynamic>>.from(users);
            _postResults = List<Map<String, dynamic>>.from(posts);
          });
        }
      } catch (e) {
        debugPrint("Search error: $e");
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Professional Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: Container(
                height: 52,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5))
                  ],
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  decoration: InputDecoration(
                    hintText: "Search creators, trends, items...",
                    hintStyle: TextStyle(color: Colors.grey.withOpacity(0.7)),
                    prefixIcon: Icon(Iconsax.search_normal, color: theme.colorScheme.primary),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ),

            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _buildTag(context, "For You"),
                  _buildTag(context, "Art"),
                  _buildTag(context, "Photography"),
                  _buildTag(context, "Design"),
                  _buildTag(context, "Tech"),
                ],
              ),
            ),
            
            const SizedBox(height: 16),

            Expanded(
              child: _searchController.text.isNotEmpty 
                ? _buildSearchResults() 
                : _buildDiscoveryGrid(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_userResults.isEmpty && _postResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Iconsax.user_search, size: 60, color: Colors.grey.withOpacity(0.3)),
            const SizedBox(height: 16),
            const Text("No results found.", style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        if (_userResults.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12.0),
            child: Text("Creators", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ),
          ..._userResults.map((user) => UserListTile(user: user)),
        ],
        if (_postResults.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12.0),
            child: Text("Posts", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: MediaQuery.of(context).size.width > 800 ? 5 : 3,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
            ),
            itemCount: _postResults.length,
            itemBuilder: (context, index) {
              final post = _postResults[index];
              return GestureDetector(
                onTap: () => context.push('/home/post', extra: {'postData': post, 'heroTag': 'search_post_${post['id']}'}),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(post['image_url'] ?? '', fit: BoxFit.cover),
                ),
              );
            },
          ),
        ],
      ],
    );
  }

  Widget _buildDiscoveryGrid() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: SupabaseService.streamPosts(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        
        var posts = snapshot.data!;
        if (_selectedTag != "For You") {
          // Simulated filtering by caption for tags
          posts = posts.where((p) => (p['caption'] ?? '').toLowerCase().contains(_selectedTag.toLowerCase())).toList();
        }

        if (posts.isEmpty) {
          return Center(
            child: Text("No posts found for #$_selectedTag", style: const TextStyle(color: Colors.grey)),
          );
        }

        return MasonryGridView.count(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          crossAxisCount: MediaQuery.of(context).size.width > 800 ? 4 : 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          itemCount: posts.length,
          itemBuilder: (context, index) {
            final post = posts[index];
            final heroTag = 'search_${post['id']}';
            return GestureDetector(
              onTap: () => context.push('/home/post', extra: {
                'postData': post,
                'heroTag': heroTag,
              }),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Hero(
                  tag: heroTag,
                  child: Image.network(post['image_url'] ?? '', fit: BoxFit.cover),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTag(BuildContext context, String text) {
    final theme = Theme.of(context);
    final isSelected = _selectedTag == text;
    return GestureDetector(
      onTap: () => setState(() => _selectedTag = text),
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? theme.colorScheme.primary : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(25),
          border: Border.all(color: isSelected ? theme.colorScheme.primary : theme.dividerColor),
          boxShadow: isSelected ? [BoxShadow(color: theme.colorScheme.primary.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))] : null,
        ),
        child: Center(
          child: Text(
            text, 
            style: TextStyle(
              fontWeight: FontWeight.bold, 
              color: isSelected ? Colors.white : theme.colorScheme.onSurface.withOpacity(0.7)
            )
          ),
        ),
      ),
    );
  }
}
