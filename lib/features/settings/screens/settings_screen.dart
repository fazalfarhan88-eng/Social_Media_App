import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:social_media_app/core/services/supabase_service.dart';
import 'package:social_media_app/core/theme/theme_provider.dart';
import 'package:social_media_app/core/widgets/custom_text_field.dart';
import 'package:social_media_app/core/utils/app_utils.dart';
import 'package:image_picker/image_picker.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _nameController = TextEditingController();
  final _bioController = TextEditingController();
  bool _isLoading = false;
  String? _avatarUrl;

  final List<Color> _themeColors = [
    const Color(0xFF6366F1), // Indigo (Default)
    const Color(0xFFEC4899), // Pink
    const Color(0xFFF59E0B), // Amber
    const Color(0xFF10B981), // Emerald
    const Color(0xFF3B82F6), // Blue
    const Color(0xFF8B5CF6), // Violet
    const Color(0xFFEF4444), // Red
  ];

  @override
  void initState() {
    super.initState();
    _fetchCurrentProfile();
  }

  Future<void> _fetchCurrentProfile() async {
    final user = SupabaseService.currentUser;
    if (user == null) return;
    
    final data = await SupabaseService.client.from('profiles').select().eq('id', user.id).single();
    setState(() {
      _nameController.text = data['full_name'] ?? '';
      _bioController.text = data['bio'] ?? '';
      _avatarUrl = data['avatar_url'];
    });
  }

  Future<void> _pickAndUploadImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    
    if (image == null) return;

    setState(() => _isLoading = true);
    try {
      final bytes = await image.readAsBytes();
      final fileName = 'avatar_${SupabaseService.currentUser!.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final url = await SupabaseService.uploadImageBytes(bytes, 'profiles', fileName);
      await SupabaseService.updateProfile(avatarUrl: url);
      setState(() => _avatarUrl = url);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Profile picture updated!")));
    } catch (e) {
      debugPrint('AVATAR UPLOAD ERROR: $e');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Upload failed: $e"), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      appBar: AppBar(title: const Text("Settings")),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: ListView(
        children: [
          const SizedBox(height: 24),
          Center(
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 60,
                  backgroundImage: NetworkImage(_avatarUrl ?? AppUtils.defaultAvatar),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: GestureDetector(
                    onTap: _isLoading ? null : _pickAndUploadImage,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: theme.colorScheme.primary, shape: BoxShape.circle),
                      child: _isLoading
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Iconsax.camera, color: Colors.white, size: 20),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Center(child: Text("Edit Profile Image", style: theme.textTheme.bodyMedium)),
          const SizedBox(height: 32),
          _buildSectionHeader(context, "Account Information"),
          ListTile(
            leading: const Icon(Iconsax.user),
            title: const Text("Full Name"),
            subtitle: Text(_nameController.text.isEmpty ? "Not set" : _nameController.text),
            trailing: const Icon(Iconsax.edit_2, size: 18),
            onTap: () => _showEditDialog("Update Name", _nameController, "full_name"),
          ),
          ListTile(
            leading: const Icon(Iconsax.document_text),
            title: const Text("Bio"),
            subtitle: Text(_bioController.text.isEmpty ? "Not set" : _bioController.text),
            trailing: const Icon(Iconsax.edit_2, size: 18),
            onTap: () => _showEditDialog("Update Bio", _bioController, "bio"),
          ),
          
          _buildSectionHeader(context, "Preferences"),
          ListTile(
            leading: const Icon(Iconsax.moon),
            title: const Text("Dark Mode"),
            trailing: Switch(
              value: themeProvider.isDarkMode,
              onChanged: (val) {
                themeProvider.toggleTheme(val);
              },
            ),
          ),

          // --- Custom Color Picker Section ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Iconsax.colorfilter, size: 22, color: Colors.grey),
                    const SizedBox(width: 12),
                    Text("Theme Color", style: theme.textTheme.bodyLarge),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 45,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _themeColors.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (context, index) {
                      final color = _themeColors[index];
                      final isSelected = themeProvider.primaryColor.value == color.value;
                      return GestureDetector(
                        onTap: () => themeProvider.setPrimaryColor(color),
                        child: Container(
                          width: 45,
                          height: 45,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: isSelected
                              ? Border.all(color: theme.brightness == Brightness.dark ? Colors.white : Colors.black, width: 3)
                              : null,
                            boxShadow: [
                              BoxShadow(
                                color: color.withOpacity(0.4),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              )
                            ]
                          ),
                          child: isSelected
                            ? const Icon(Icons.check, color: Colors.white, size: 20)
                            : null,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          ListTile(
            leading: const Icon(Iconsax.notification),
            title: const Text("Notifications"),
            onTap: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text("Notifications"),
                  content: const Text("Notification settings will be available in the next update."),
                  actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("OK"))],
                ),
              );
            },
          ),

          _buildSectionHeader(context, "Actions"),
          ListTile(
            leading: const Icon(Iconsax.info_circle),
            title: const Text("About & Help"),
            onTap: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text("About & Help"),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Iconsax.flash, size: 40, color: Colors.blue),
                      const SizedBox(height: 10),
                      const Text("Social Media App 1.0.0", style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      const Text("A modern social media platform built with Flutter and Supabase."),
                      const SizedBox(height: 10),
                      const Text("Developed by Muhammad Farhan"),
                    ],
                  ),
                  actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("Close"))],
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Iconsax.logout, color: Colors.orange),
            title: const Text("Log Out", style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
            onTap: () async {
               await SupabaseService.signOut();
               if (mounted) context.go('/');
            },
          ),
          ListTile(
            leading: const Icon(Iconsax.trash, color: Colors.red),
            title: const Text("Delete Account", style: TextStyle(color: Colors.red)),
            onTap: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text("Delete Account"),
                  content: const Text("Are you sure? This cannot be undone."),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
                    TextButton(
                      onPressed: () async {
                        try {
                          await SupabaseService.client.from('profiles').delete().eq('id', SupabaseService.currentUser!.id);
                          await SupabaseService.signOut();
                          if (mounted) context.go('/');
                        } catch (e) {
                          debugPrint('DELETE ERROR: $e');
                        }
                      },
                      child: const Text("Delete", style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
        ),
      ),
    );
  }

  void _showEditDialog(String title, TextEditingController controller, String field) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: CustomTextField(controller: controller, hintText: "Enter $title"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              setState(() => _isLoading = true);
              try {
                if (field == 'full_name') {
                  await SupabaseService.updateProfile(fullName: controller.text.trim());
                } else {
                  await SupabaseService.updateProfile(bio: controller.text.trim());
                }
                setState(() {});
              } catch (e) {
                debugPrint('UPDATE ERROR: $e');
              } finally {
                setState(() => _isLoading = false);
              }
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary.withOpacity(0.7),
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}
