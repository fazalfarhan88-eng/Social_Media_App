import 'package:intl/intl.dart';

class AppUtils {
  static const String defaultAvatar = 'https://www.gravatar.com/avatar/00000000000000000000000000000000?d=mp&f=y';
  
  static String formatTime(String? dateStr) {
    if (dateStr == null) return 'Just now';
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final diff = now.difference(date);
      
      if (diff.inDays > 7) {
        return DateFormat('MMM d').format(date);
      } else if (diff.inDays > 0) {
        return "${diff.inDays}d ago";
      } else if (diff.inHours > 0) {
        return "${diff.inHours}h ago";
      } else if (diff.inMinutes > 0) {
        return "${diff.inMinutes}m ago";
      } else {
        return "Just now";
      }
    } catch (e) {
      return 'Just now';
    }
  }

  static String formatChatTime(String? dateStr) {
     if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      if (now.difference(date).inDays > 0) {
        if (now.difference(date).inDays < 7) {
          return DateFormat('E').format(date); // Mon, Tue, etc.
        }
        return DateFormat('MM/dd').format(date);
      }
      return DateFormat('HH:mm').format(date);
    } catch (e) {
      return '';
    }
  }
}
