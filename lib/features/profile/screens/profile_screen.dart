import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:go_router/go_router.dart';
import 'package:social_media_app/core/services/supabase_service.dart';
import 'package:social_media_app/core/utils/auth_guard.dart';
import 'package:social_media_app/core/widgets/custom_button.dart';
import 'package:social_media_app/core/widgets/auth_landing_widget.dart';
import 'package:social_media_app/features/profile/services/profile_service.dart';

class ProfileScreen extends StatefulWidget {
  final String? userId;
  const ProfileScreen({Key? key, this.userId}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? profileData;
  bool isLoading = true;
  bool _isFollowing = false;
  bool _profileNotFound = false;
  int _postsCount = 0;
  int _followersCount = 0;
  int _followingCount = 0;

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    final user = SupabaseService.client.auth.currentSession?.user;
    final effectiveUserId = widget.userId ?? user?.id;

    if (effectiveUserId == null) {
      if (mounted) setState(() => isLoading = false);
      return;
    }
    
    try {
      final futures = <Future<dynamic>>[
        SupabaseService.client.from('profiles').select().eq('id', effectiveUserId).single(),
        SupabaseService.client.from('posts_with_profiles').select('id').eq('user_id', effectiveUserId),
        SupabaseService.client.from('follows').select('id').eq('following_id', effectiveUserId),
        SupabaseService.client.from('follows').select('id').eq('follower_id', effectiveUserId),
      ];

      if (user != null) {
        futures.add(SupabaseService.client.from('follows').select().eq('follower_id', user.id).eq('following_id', effectiveUserId).maybeSingle());
      }

      final results = await Future.wait(futures);

      if (mounted) {
        setState(() {
          profileData = results[0] as Map<String, dynamic>;
          _postsCount = (results[1] as List).length;
          _followersCount = (results[2] as List).length;
          _followingCount = (results[3] as List).length;
          _isFollowing = results.length > 4 && results[4] != null;
          
          isLoading = false;
          _profileNotFound = false;
        });
      }
    } catch (e) {
      debugPrint('PROFILE FETCH ERROR: $e');
      if (mounted) {
        setState(() {
          isLoading = false;
          if (e.toString().contains('PGRST116')) {
            _profileNotFound = true;
          }
        });
      }
    }
  }

  void _toggleFollow() {
    AuthGuard.executeWithAuth(context, () {
      final oldState = _isFollowing;
      setState(() {
        _isFollowing = !_isFollowing;
        _followersCount += _isFollowing ? 1 : -1;
      });

      try {
        if (_isFollowing) {
          SupabaseService.followUser(profileData!['id']);
        } else {
          SupabaseService.unfollowUser(profileData!['id']);
        }
      } catch (e) {
        setState(() {
          _isFollowing = oldState;
          _followersCount += _isFollowing ? 1 : -1;
        });
      }
    });
  }

  Future<void> _uploadAvatar() async {
    final newUrl = await ProfileService.pickCropAndUploadAvatar(context);
    if (newUrl != null && mounted) {
      setState(() {
        profileData = {...?profileData, 'avatar_url': newUrl};
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile picture updated!'), backgroundColor: Colors.green),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final session = SupabaseService.client.auth.currentSession;
    final user = session?.user;

    if (user == null && widget.userId == null) {
      return const Scaffold(
        body: AuthLandingWidget(
          title: "Your Profile",
          message: "Sign in to share your moments and connect with the world.",
          icon: Iconsax.profile_circle,
        ),
      );
    }

    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_profileNotFound) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Iconsax.user_search, size: 64, color: Colors.orange),
                const SizedBox(height: 24),
                const Text("Profile Not Found", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                const Text(
                  "It seems this profile does not exist or has been removed.",
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                CustomButton(
                  text: "Go Back",
                  onPressed: () => context.pop(),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final isMe = SupabaseService.currentUser?.id == profileData?['id'];
    final username = profileData?['username'] ?? 'unknown';
    final fullName = profileData?['full_name'] ?? 'User';
    final avatarUrl = profileData?['avatar_url'] ?? 'https://i.pravatar.cc/150?u=$username';

    return Scaffold(
      appBar: AppBar(
        title: Text(username, style: theme.textTheme.titleLarge),
        actions: [
          if (isMe)
            IconButton(
              icon: const Icon(Iconsax.setting_2),
              onPressed: () => context.push('/settings'),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchProfile,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: Column(
            children: [
              const SizedBox(height: 24),
              // Avatar with tap-to-change overlay
              GestureDetector(
                onTap: isMe ? _uploadAvatar : null,
                child: Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: theme.colorScheme.primary, width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: theme.colorScheme.primary.withOpacity(0.2),
                            blurRadius: 20,
                            spreadRadius: 5,
                          )
                        ],
                      ),
                      child: CircleAvatar(
                        radius: 55,
                        backgroundColor: theme.colorScheme.surface,
                        backgroundImage: NetworkImage(avatarUrl),
                      ),
                    ),
                    if (isMe)
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(Iconsax.camera, size: 16, color: Colors.white),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text(fullName, style: theme.textTheme.displayLarge?.copyWith(fontSize: 26)),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40.0),
                child: Text(
                  profileData?['bio'] ?? "Explore my world on SocialApp",
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium,
                ),
              ),
              const SizedBox(height: 32),
              
              // Stats
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5))
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildStatColumn(context, "Posts", _postsCount.toString(), null),
                    _buildStatDivider(context),
                    _buildStatColumn(context, "Followers", _followersCount.toString(), () => context.push('/profile/${profileData!['id']}/followers')),
                    _buildStatDivider(context),
                    _buildStatColumn(context, "Following", _followingCount.toString(), () => context.push('/profile/${profileData!['id']}/following')),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              
              // Actions
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Row(
                  children: [
                    if (isMe) ...[
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => context.push('/settings'),
                          icon: const Icon(Iconsax.user_edit),
                          label: const Text("Edit Profile & Picture"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.colorScheme.primary,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(double.infinity, 50),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                          ),
                        ),
                      ),
                    ] else ...[
                      Expanded(
                        child: CustomButton(
                          text: _isFollowing ? "Remove Friend" : "Add Friend",
                          onPressed: _toggleFollow,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => context.push('/chat_detail/${profileData!['id']}'),
                          icon: const Icon(Iconsax.message_2),
                          label: const Text("Message"),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 50),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                            side: BorderSide(color: theme.colorScheme.primary),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 32),
              
              // Posts Grid
              _buildPostGrid(profileData!['id']),
            ],
          ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPostGrid(String userId) {
    final theme = Theme.of(context);
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: SupabaseService.streamUserPosts(userId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        
        final posts = snapshot.data!;
        if (posts.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Iconsax.image, size: 48, color: Colors.grey.withOpacity(0.5)),
                const SizedBox(height: 12),
                Text("No posts yet", style: theme.textTheme.bodyMedium),
              ],
            ),
          );
        }

        return GridView.builder(
          padding: const EdgeInsets.all(12),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
          ),
          itemCount: posts.length,
          itemBuilder: (context, index) {
            final post = posts[index];
            final heroTag = 'profile_${post['id']}';
            return GestureDetector(
              onTap: () => context.push('/home/post', extra: {
                'postData': post,
                'heroTag': heroTag,
              }),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
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

  Widget _buildStatColumn(BuildContext context, String label, String value, VoidCallback? onTap) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Text(value, style: theme.textTheme.displayLarge?.copyWith(fontSize: 22, color: theme.colorScheme.primary)),
          const SizedBox(height: 4),
          Text(label, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildStatDivider(BuildContext context) {
    return Container(
      height: 30,
      width: 1,
      color: Colors.grey.withOpacity(0.2),
    );
  }
}
