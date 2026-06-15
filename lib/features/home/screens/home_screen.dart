import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:go_router/go_router.dart';
import 'package:social_media_app/features/home/widgets/status_list.dart';
import 'package:social_media_app/features/home/widgets/post_card.dart';
import 'package:social_media_app/core/services/supabase_service.dart';
import 'package:social_media_app/core/utils/auth_guard.dart';
import 'package:google_fonts/google_fonts.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Key _feedKey = UniqueKey();

  Future<void> _refreshFeed() async {
    setState(() {
      _feedKey = UniqueKey();
    });
    await Future.delayed(const Duration(seconds: 1));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(70),
        child: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: AppBar(
              backgroundColor: theme.scaffoldBackgroundColor.withOpacity(0.7),
              surfaceTintColor: Colors.transparent,
              title: Text(
                "SocialApp", 
                style: GoogleFonts.outfit(
                  fontSize: 26, 
                  fontWeight: FontWeight.w900, 
                  color: theme.colorScheme.primary,
                  letterSpacing: -1.0
                )
              ),
              centerTitle: false,
              actions: [
                _AppBarAction(
                  icon: Iconsax.notification,
                  onPressed: () => AuthGuard.executeWithAuth(context, () => context.push('/notifications')),
                ),
                _AppBarAction(
                  icon: Iconsax.message_2,
                  onPressed: () => AuthGuard.executeWithAuth(context, () => context.push('/chats')),
                ),
                const SizedBox(width: 12),
              ],
            ),
          ),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final bool isDesktop = constraints.maxWidth > 800;
          
          Widget feedContent = RefreshIndicator(
            onRefresh: _refreshFeed,
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(child: SizedBox(height: MediaQuery.of(context).padding.top + 80)),
                const SliverToBoxAdapter(child: StatusList()),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20),
                    child: Row(
                      children: [
                        Text("Latest Feed", style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold, fontSize: 18)),
                        const Spacer(),
                        Icon(Iconsax.sort, size: 20, color: theme.colorScheme.primary),
                      ],
                    ),
                  ),
                ),
                StreamBuilder<List<Map<String, dynamic>>>(
                  key: _feedKey,
                  stream: SupabaseService.streamPosts(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const SliverFillRemaining(
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    if (snapshot.hasError) {
                      return SliverToBoxAdapter(
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(40.0),
                            child: Text("Unable to load feed. Please check your connection.", textAlign: TextAlign.center, style: theme.textTheme.bodyMedium),
                          ),
                        ),
                      );
                    }
                    
                    final posts = snapshot.data ?? [];
                    if (posts.isEmpty) {
                      return SliverFillRemaining(
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Iconsax.image, size: 64, color: theme.colorScheme.primary.withOpacity(0.2)),
                              const SizedBox(height: 16),
                              Text("Your feed is empty.", style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold)),
                              Text("Start following people or create a post!", style: theme.textTheme.bodyMedium),
                            ],
                          ),
                        ),
                      );
                    }
      
                    return SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final post = posts[index];
                          return PostCard(
                            postData: post,
                            heroTag: 'feed_${post['id']}',
                          );
                        },
                        childCount: posts.length,
                      ),
                    );
                  },
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            ),
          );

          if (isDesktop) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 5,
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 600),
                      child: feedContent,
                    ),
                  ),
                ),
                Container(width: 1, color: theme.dividerColor.withOpacity(0.5)),
                Expanded(
                  flex: 3,
                  child: _buildDesktopSidebar(context, theme),
                ),
              ],
            );
          }

          return feedContent;
        },
      ),
    );
  }

  Widget _buildDesktopSidebar(BuildContext context, ThemeData theme) {
    return Container(
      color: theme.colorScheme.surface,
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: MediaQuery.of(context).padding.top + 80),
          Text("Suggested Creators", style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: SupabaseService.client.from('profiles').select().limit(5),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final users = snapshot.data!;
                return ListView.builder(
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    final user = users[index];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      onTap: () => context.push('/profile/${user['id']}'),
                      leading: CircleAvatar(
                        backgroundImage: NetworkImage(user['avatar_url'] ?? 'https://www.gravatar.com/avatar/00000000000000000000000000000000?d=mp&f=y'),
                      ),
                      title: Text(user['full_name'] ?? user['username'] ?? 'Unknown', maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text('@${user['username'] ?? ''}', style: const TextStyle(fontSize: 12)),
                      trailing: const Icon(Iconsax.arrow_right_3, size: 16, color: Colors.grey),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _AppBarAction extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;

  const _AppBarAction({required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(left: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        icon: Icon(icon, size: 22),
        onPressed: onPressed,
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}
