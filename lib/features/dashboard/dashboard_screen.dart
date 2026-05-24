import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';
import 'package:social_media_app/core/utils/auth_guard.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';

class DashboardScreen extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const DashboardScreen({
    Key? key,
    required this.navigationShell,
  }) : super(key: key);

  void _onItemTapped(BuildContext context, int index) {
    if (index == 2) {
      AuthGuard.executeWithAuth(context, () {
        context.push('/create_post');
      });
      return;
    }
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isDesktop = false;
    bool isWeb = kIsWeb;
    
    if (!kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
      isDesktop = true;
    }

    return Scaffold(
      body: isWeb 
          ? _buildWebLayout(context) 
          : (isDesktop ? _buildDesktopLayout(context) : _buildMobileLayout(context)),
    );
  }

  Widget _buildMobileLayout(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Expanded(child: navigationShell),
        Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, -5),
              )
            ],
          ),
          child: NavigationBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            indicatorColor: theme.colorScheme.primary.withOpacity(0.1),
            selectedIndex: navigationShell.currentIndex,
            labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
            onDestinationSelected: (index) => _onItemTapped(context, index),
            destinations: [
              NavigationDestination(
                icon: Icon(Iconsax.home, color: navigationShell.currentIndex == 0 ? theme.colorScheme.primary : Colors.grey), 
                label: "Home"
              ),
              NavigationDestination(
                icon: Icon(Iconsax.search_normal, color: navigationShell.currentIndex == 1 ? theme.colorScheme.primary : Colors.grey), 
                label: "Search"
              ),
              NavigationDestination(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: theme.colorScheme.primary, shape: BoxShape.circle),
                  child: const Icon(Iconsax.add, color: Colors.white)
                ), 
                label: "Post"
              ),
              NavigationDestination(
                icon: Icon(Iconsax.notification, color: navigationShell.currentIndex == 3 ? theme.colorScheme.primary : Colors.grey), 
                label: "Activity"
              ),
              NavigationDestination(
                icon: Icon(Iconsax.profile_circle, color: navigationShell.currentIndex == 4 ? theme.colorScheme.primary : Colors.grey), 
                label: "Profile"
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopLayout(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          width: 250,
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            border: Border(right: BorderSide(color: theme.dividerColor)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 40),
              Text("SocialApp", style: theme.textTheme.displayLarge?.copyWith(fontSize: 28, color: theme.colorScheme.primary)),
              const SizedBox(height: 40),
              _buildNavItem(Iconsax.home, "Home", 0, context),
              _buildNavItem(Iconsax.search_normal, "Search", 1, context),
              _buildNavItem(Iconsax.add_square, "Post", 2, context),
              _buildNavItem(Iconsax.notification, "Activity", 3, context),
              _buildNavItem(Iconsax.profile_circle, "Profile", 4, context),
              const Spacer(),
              _buildNavItem(Iconsax.setting_2, "Settings", -1, context),
              const SizedBox(height: 20),
            ],
          ),
        ),
        Expanded(child: navigationShell),
      ],
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index, BuildContext context) {
    final theme = Theme.of(context);
    bool isSelected = index >= 0 && navigationShell.currentIndex == index;
    return ListTile(
      leading: Icon(icon, color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface.withOpacity(0.6)),
      title: Text(label, style: TextStyle(
        color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface.withOpacity(0.6),
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal
      )),
      selected: isSelected,
      onTap: () {
        if (index == -1) {
          context.push('/settings');
        } else {
          _onItemTapped(context, index);
        }
      },
    );
  }

  Widget _buildWebLayout(BuildContext context) {
    final theme = Theme.of(context);
    // Separate layout for Web View as requested
    return Row(
      children: [
        Container(
          width: 80,
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            border: Border(right: BorderSide(color: theme.dividerColor)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 20),
              Icon(Iconsax.camera, color: theme.colorScheme.primary, size: 32),
              const SizedBox(height: 40),
              IconButton(
                icon: Icon(Iconsax.home, color: navigationShell.currentIndex == 0 ? theme.colorScheme.primary : Colors.grey),
                onPressed: () => _onItemTapped(context, 0),
              ),
              const SizedBox(height: 20),
              IconButton(
                icon: Icon(Iconsax.search_normal, color: navigationShell.currentIndex == 1 ? theme.colorScheme.primary : Colors.grey),
                onPressed: () => _onItemTapped(context, 1),
              ),
              const SizedBox(height: 20),
              IconButton(
                icon: Icon(Iconsax.add_square, color: navigationShell.currentIndex == 2 ? theme.colorScheme.primary : Colors.grey),
                onPressed: () => _onItemTapped(context, 2),
              ),
              const SizedBox(height: 20),
              IconButton(
                icon: Icon(Iconsax.notification, color: navigationShell.currentIndex == 3 ? theme.colorScheme.primary : Colors.grey),
                onPressed: () => _onItemTapped(context, 3),
              ),
              const SizedBox(height: 20),
              IconButton(
                icon: Icon(Iconsax.profile_circle, color: navigationShell.currentIndex == 4 ? theme.colorScheme.primary : Colors.grey),
                onPressed: () => _onItemTapped(context, 4),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Iconsax.setting_2, color: Colors.grey),
                onPressed: () => context.push('/settings'),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
        Expanded(child: navigationShell),
      ],
    );
  }
}
