import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:social_media_app/features/auth/screens/login_screen.dart';
import 'package:social_media_app/features/auth/screens/register_screen.dart';
import 'package:social_media_app/features/dashboard/dashboard_screen.dart';
import 'package:social_media_app/features/post_creation/screens/create_post_screen.dart';
import 'package:social_media_app/features/notifications/screens/notifications_screen.dart';
import 'package:social_media_app/features/chat/screens/chat_list_screen.dart';
import 'package:social_media_app/features/chat/screens/chat_detail_screen.dart';
import 'package:social_media_app/features/settings/screens/settings_screen.dart';
import 'package:social_media_app/features/splash/screens/splash_screen.dart';
import 'package:social_media_app/features/home/screens/home_screen.dart';
import 'package:social_media_app/features/search/screens/search_screen.dart';
import 'package:social_media_app/features/profile/screens/profile_screen.dart';
import 'package:social_media_app/features/profile/screens/user_list_screen.dart';
import 'package:social_media_app/features/home/screens/post_detail_screen.dart';

import 'package:social_media_app/features/home/screens/create_story_screen.dart';
import 'package:social_media_app/features/home/screens/story_view_screen.dart';
import 'package:social_media_app/core/services/supabase_service.dart';
import 'package:social_media_app/features/post_creation/screens/upload_screen.dart';

class AppRouter {
  static final _rootNavigatorKey = GlobalKey<NavigatorState>();
  
  static final router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/splash',
    redirect: (context, state) {
      final isLoggedIn = SupabaseService.currentUser != null;
      final isGoingToLogin = state.matchedLocation == '/' || state.matchedLocation == '/register';

      if (!isLoggedIn && !isGoingToLogin && state.matchedLocation != '/splash') {
        return '/';
      }

      if (isLoggedIn && isGoingToLogin) {
        return '/home';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      
      // PERSISTENT NAVIGATION SHELL
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return DashboardScreen(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                builder: (context, state) => const HomeScreen(),
                routes: [
                  GoRoute(
                    path: 'post', // /home/post
                    builder: (context, state) {
                      final extras = state.extra as Map<String, dynamic>;
                      return PostDetailScreen(
                        postData: extras['postData'],
                        heroTag: extras['heroTag'],
                        autoOpenComments: extras['autoOpenComments'] ?? false,
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/search',
                builder: (context, state) => const SearchScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/create_post_placeholder',
                builder: (context, state) => const SizedBox.shrink(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/notifications',
                builder: (context, state) => const NotificationsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (context, state) => const ProfileScreen(),
                routes: [
                  GoRoute(
                    path: ':id',
                    builder: (context, state) {
                      final id = state.pathParameters['id'];
                      return ProfileScreen(userId: id);
                    },
                    routes: [
                      GoRoute(
                        path: 'followers',
                        builder: (context, state) => UserListScreen(
                          title: "Followers",
                          userId: state.pathParameters['id']!,
                          showFollowers: true,
                        ),
                      ),
                      GoRoute(
                        path: 'following',
                        builder: (context, state) => UserListScreen(
                          title: "Following",
                          userId: state.pathParameters['id']!,
                          showFollowers: false,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),

      // Global Routes (Overlaying the shell)
      GoRoute(
        path: '/create_post',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const CreatePostScreen(),
      ),
      GoRoute(
        path: '/ai_upload',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const UploadScreen(),
      ),
      GoRoute(
        path: '/create_story',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const CreateStoryScreen(),
      ),
      GoRoute(
        path: '/story_view',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final story = state.extra as Map<String, dynamic>;
          return StoryViewScreen(story: story);
        },
      ),
      GoRoute(
        path: '/chats',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const ChatListScreen(),
      ),
      GoRoute(
        path: '/chat_detail/:id',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return ChatDetailScreen(chatId: id);
        },
      ),
      GoRoute(
        path: '/settings',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const SettingsScreen(),
      ),


    ],
  );
}
