import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class NotebookIcon {
  final int id;
  final IconData icon;
  final String name;

  const NotebookIcon({
    required this.id,
    required this.icon,
    required this.name,
  });
}

class NotebookIconsRepository {
  static const List<NotebookIcon> icons = [
    // General
    NotebookIcon(id: 1, icon: Icons.folder_rounded, name: 'Folder'),
    NotebookIcon(id: 2, icon: Icons.folder_open_rounded, name: 'Open Folder'),
    NotebookIcon(
      id: 3,
      icon: Icons.folder_special_rounded,
      name: 'Special Folder',
    ),
    NotebookIcon(id: 4, icon: Icons.folder_zip_rounded, name: 'Archive'),

    // Work
    NotebookIcon(id: 5, icon: Icons.work_rounded, name: 'Work'),
    NotebookIcon(id: 6, icon: Icons.business_rounded, name: 'Business'),
    NotebookIcon(id: 7, icon: Icons.meeting_room_rounded, name: 'Meeting'),
    NotebookIcon(id: 8, icon: Icons.assignment_rounded, name: 'Assignment'),
    NotebookIcon(id: 9, icon: Icons.description_rounded, name: 'Document'),
    NotebookIcon(id: 10, icon: Icons.article_rounded, name: 'Article'),

    // Personal
    NotebookIcon(id: 11, icon: Icons.person_rounded, name: 'Personal'),
    NotebookIcon(id: 12, icon: Icons.home_rounded, name: 'Home'),
    NotebookIcon(id: 13, icon: Icons.family_restroom_rounded, name: 'Family'),
    NotebookIcon(id: 14, icon: Icons.favorite_rounded, name: 'Favorites'),
    NotebookIcon(id: 15, icon: Icons.favorite_border_rounded, name: 'Love'),

    // Education
    NotebookIcon(id: 16, icon: Icons.school_rounded, name: 'School'),
    NotebookIcon(id: 17, icon: Icons.book_rounded, name: 'Book'),
    NotebookIcon(id: 18, icon: Icons.library_books_rounded, name: 'Library'),
    NotebookIcon(id: 19, icon: Icons.science_rounded, name: 'Science'),
    NotebookIcon(id: 20, icon: Icons.calculate_rounded, name: 'Math'),
    NotebookIcon(id: 21, icon: Icons.history_rounded, name: 'History'),
    NotebookIcon(id: 22, icon: Icons.language_rounded, name: 'Language'),

    // Projects
    NotebookIcon(id: 23, icon: Icons.code_rounded, name: 'Code'),
    NotebookIcon(id: 24, icon: Icons.build_rounded, name: 'Build'),
    NotebookIcon(id: 25, icon: Icons.engineering_rounded, name: 'Engineering'),
    NotebookIcon(
      id: 26,
      icon: Icons.architecture_rounded,
      name: 'Architecture',
    ),

    // Creativity
    NotebookIcon(id: 27, icon: Icons.brush_rounded, name: 'Art'),
    NotebookIcon(id: 28, icon: Icons.music_note_rounded, name: 'Music'),
    NotebookIcon(id: 29, icon: Icons.camera_alt_rounded, name: 'Photography'),
    NotebookIcon(id: 30, icon: Icons.videocam_rounded, name: 'Video'),
    NotebookIcon(id: 31, icon: Icons.palette_rounded, name: 'Design'),
    NotebookIcon(id: 32, icon: Icons.create_rounded, name: 'Writing'),

    // Health
    NotebookIcon(id: 33, icon: Icons.fitness_center_rounded, name: 'Fitness'),
    NotebookIcon(id: 34, icon: Icons.psychology_rounded, name: 'Psychology'),
    NotebookIcon(id: 35, icon: Icons.spa_rounded, name: 'Wellness'),

    // Finance
    NotebookIcon(id: 36, icon: Icons.account_balance_rounded, name: 'Bank'),
    NotebookIcon(id: 37, icon: Icons.attach_money_rounded, name: 'Money'),
    NotebookIcon(id: 38, icon: Icons.trending_up_rounded, name: 'Investments'),
    NotebookIcon(id: 39, icon: Icons.receipt_rounded, name: 'Expenses'),

    // Travel
    NotebookIcon(id: 40, icon: Icons.flight_rounded, name: 'Travel'),
    NotebookIcon(id: 41, icon: Icons.hotel_rounded, name: 'Hotel'),
    NotebookIcon(id: 42, icon: Icons.map_rounded, name: 'Map'),
    NotebookIcon(id: 43, icon: Icons.explore_rounded, name: 'Explore'),

    // Technology
    NotebookIcon(id: 44, icon: Icons.computer_rounded, name: 'Computer'),
    NotebookIcon(id: 45, icon: Icons.phone_rounded, name: 'Mobile'),
    NotebookIcon(id: 46, icon: Icons.wifi_rounded, name: 'Internet'),
    NotebookIcon(id: 47, icon: Icons.security_rounded, name: 'Security'),

    // Food
    NotebookIcon(id: 48, icon: Icons.restaurant_rounded, name: 'Restaurant'),
    NotebookIcon(id: 49, icon: Icons.kitchen_rounded, name: 'Kitchen'),
    NotebookIcon(id: 50, icon: Icons.local_dining_rounded, name: 'Dining'),
    NotebookIcon(id: 51, icon: Icons.cake_rounded, name: 'Baking'),

    // Sports
    NotebookIcon(id: 52, icon: Icons.sports_soccer_rounded, name: 'Soccer'),
    NotebookIcon(
      id: 53,
      icon: Icons.sports_basketball_rounded,
      name: 'Basketball',
    ),
    NotebookIcon(id: 54, icon: Icons.sports_tennis_rounded, name: 'Tennis'),
    NotebookIcon(id: 55, icon: Icons.directions_run_rounded, name: 'Running'),

    // Pets
    NotebookIcon(id: 56, icon: Icons.pets_rounded, name: 'Pets'),
    NotebookIcon(id: 57, icon: Icons.emoji_nature_rounded, name: 'Nature'),

    // Ideas
    NotebookIcon(id: 58, icon: Icons.lightbulb_rounded, name: 'Ideas'),
    NotebookIcon(id: 59, icon: Icons.psychology_alt_rounded, name: 'Thoughts'),
    NotebookIcon(id: 60, icon: Icons.auto_awesome_rounded, name: 'Inspiration'),
    NotebookIcon(id: 61, icon: Icons.star_rounded, name: 'Important'),

    // Internet
    NotebookIcon(id: 62, icon: Icons.cloud_rounded, name: 'Cloud'),
    NotebookIcon(id: 63, icon: Icons.share_rounded, name: 'Share'),
    NotebookIcon(id: 64, icon: Icons.link_rounded, name: 'Link'),
    NotebookIcon(id: 65, icon: Icons.public_rounded, name: 'Public'),
    NotebookIcon(id: 66, icon: Icons.router_rounded, name: 'Router'),
    NotebookIcon(id: 67, icon: Icons.signal_wifi_4_bar_rounded, name: 'WiFi'),
    NotebookIcon(id: 68, icon: Icons.bluetooth_rounded, name: 'Bluetooth'),
    NotebookIcon(id: 69, icon: Icons.nfc_rounded, name: 'NFC'),
    NotebookIcon(id: 70, icon: Icons.satellite_alt_rounded, name: 'Satellite'),
    NotebookIcon(id: 71, icon: Icons.cell_tower_rounded, name: 'Cell Tower'),

    // Mobile
    NotebookIcon(id: 72, icon: Icons.phone_android_rounded, name: 'Android'),
    NotebookIcon(id: 73, icon: Icons.phone_iphone_rounded, name: 'iPhone'),
    NotebookIcon(id: 74, icon: Icons.tablet_rounded, name: 'Tablet'),
    NotebookIcon(id: 75, icon: Icons.laptop_rounded, name: 'Laptop'),
    NotebookIcon(id: 76, icon: Icons.desktop_windows_rounded, name: 'Desktop'),
    NotebookIcon(id: 77, icon: Icons.tv_rounded, name: 'TV'),
    NotebookIcon(id: 78, icon: Icons.watch_rounded, name: 'Smartwatch'),
    NotebookIcon(id: 79, icon: Icons.headphones_rounded, name: 'Headphones'),
    NotebookIcon(id: 80, icon: Icons.speaker_rounded, name: 'Speaker'),
    NotebookIcon(id: 81, icon: Icons.keyboard_rounded, name: 'Keyboard'),
    NotebookIcon(id: 82, icon: Icons.mouse_rounded, name: 'Mouse'),
    NotebookIcon(id: 83, icon: Icons.memory_rounded, name: 'Memory'),
    NotebookIcon(id: 84, icon: Icons.storage_rounded, name: 'Storage'),
    NotebookIcon(id: 85, icon: Icons.usb_rounded, name: 'USB'),
    NotebookIcon(id: 86, icon: Icons.power_rounded, name: 'Power'),
    NotebookIcon(
      id: 87,
      icon: Icons.battery_charging_full_rounded,
      name: 'Battery',
    ),

    // Social
    NotebookIcon(id: 88, icon: Icons.chat_rounded, name: 'Chat'),
    NotebookIcon(id: 89, icon: Icons.task_alt_rounded, name: 'Task'),
    NotebookIcon(id: 90, icon: Icons.email_rounded, name: 'Email'),
    NotebookIcon(id: 91, icon: Icons.forum_rounded, name: 'Forum'),
    NotebookIcon(id: 92, icon: Icons.group_rounded, name: 'Group'),
    NotebookIcon(id: 93, icon: Icons.people_rounded, name: 'People'),
    NotebookIcon(id: 94, icon: Icons.person_add_rounded, name: 'Add Person'),
    NotebookIcon(id: 95, icon: Icons.contact_phone_rounded, name: 'Contact'),
    NotebookIcon(
      id: 96,
      icon: Icons.notifications_rounded,
      name: 'Notifications',
    ),
    NotebookIcon(id: 97, icon: Icons.thumb_up_rounded, name: 'Like'),
    NotebookIcon(id: 98, icon: Icons.comment_rounded, name: 'Comment'),
    NotebookIcon(id: 99, icon: Icons.flag_rounded, name: 'Flag'),
    NotebookIcon(id: 100, icon: Icons.block_rounded, name: 'Block'),
    NotebookIcon(id: 101, icon: Icons.report_rounded, name: 'Report'),

    // Media
    NotebookIcon(id: 102, icon: Icons.camera_roll_rounded, name: 'Camera Roll'),
    NotebookIcon(
      id: 103,
      icon: Icons.photo_library_rounded,
      name: 'Photo Library',
    ),
    NotebookIcon(id: 104, icon: Icons.image_rounded, name: 'Image'),
    NotebookIcon(id: 105, icon: Icons.photo_rounded, name: 'Photo'),
    NotebookIcon(
      id: 106,
      icon: Icons.video_library_rounded,
      name: 'Video Library',
    ),
    NotebookIcon(id: 107, icon: Icons.movie_rounded, name: 'Movie'),
    NotebookIcon(id: 108, icon: Icons.play_circle_rounded, name: 'Play'),
    NotebookIcon(id: 109, icon: Icons.pause_rounded, name: 'Pause'),
    NotebookIcon(id: 110, icon: Icons.stop_rounded, name: 'Stop'),
    NotebookIcon(id: 111, icon: Icons.skip_next_rounded, name: 'Next'),
    NotebookIcon(id: 112, icon: Icons.skip_previous_rounded, name: 'Previous'),
    NotebookIcon(id: 113, icon: Icons.volume_up_rounded, name: 'Volume'),
    NotebookIcon(id: 114, icon: Icons.mic_rounded, name: 'Microphone'),
    NotebookIcon(
      id: 115,
      icon: Icons.screen_share_rounded,
      name: 'Screen Share',
    ),
    NotebookIcon(id: 116, icon: Icons.cast_rounded, name: 'Cast'),
    NotebookIcon(id: 117, icon: Icons.airplay_rounded, name: 'Airplay'),
    NotebookIcon(
      id: 118,
      icon: Icons.bluetooth_audio_rounded,
      name: 'Bluetooth Audio',
    ),

    // Content
    NotebookIcon(id: 119, icon: Icons.rate_review_rounded, name: 'Review'),
    NotebookIcon(id: 120, icon: Icons.star_half_rounded, name: 'Half Star'),
    NotebookIcon(id: 121, icon: Icons.star_border_rounded, name: 'Empty Star'),
    NotebookIcon(id: 122, icon: Icons.thumb_down_rounded, name: 'Thumbs Down'),
    NotebookIcon(
      id: 123,
      icon: Icons.sentiment_satisfied_rounded,
      name: 'Happy',
    ),
    NotebookIcon(
      id: 124,
      icon: Icons.sentiment_neutral_rounded,
      name: 'Neutral',
    ),
    NotebookIcon(
      id: 125,
      icon: Icons.sentiment_dissatisfied_rounded,
      name: 'Sad',
    ),
    NotebookIcon(id: 126, icon: Icons.emoji_emotions_rounded, name: 'Emoji'),
    NotebookIcon(id: 127, icon: Icons.tag_rounded, name: 'Tag'),
    NotebookIcon(id: 128, icon: Icons.label_rounded, name: 'Label'),
    NotebookIcon(id: 129, icon: Icons.bookmark_rounded, name: 'Bookmark'),
    NotebookIcon(
      id: 130,
      icon: Icons.bookmark_border_rounded,
      name: 'Bookmark Border',
    ),
    NotebookIcon(
      id: 131,
      icon: Icons.heart_broken_rounded,
      name: 'Broken Heart',
    ),
    NotebookIcon(id: 132, icon: Icons.download_rounded, name: 'Download'),
    NotebookIcon(id: 133, icon: Icons.upload_rounded, name: 'Upload'),
    NotebookIcon(id: 134, icon: Icons.print_rounded, name: 'Print'),
    NotebookIcon(id: 135, icon: Icons.copy_rounded, name: 'Copy'),
    NotebookIcon(id: 136, icon: Icons.cut_rounded, name: 'Cut'),
    NotebookIcon(id: 137, icon: Icons.paste_rounded, name: 'Paste'),
    NotebookIcon(id: 138, icon: Icons.edit_rounded, name: 'Edit'),

    // Books
    NotebookIcon(id: 139, icon: Icons.menu_book_rounded, name: 'Menu Book'),
    NotebookIcon(
      id: 140,
      icon: Icons.auto_stories_rounded,
      name: 'Auto Stories',
    ),
    NotebookIcon(
      id: 141,
      icon: Icons.text_snippet_rounded,
      name: 'Text Snippet',
    ),
    NotebookIcon(id: 142, icon: Icons.note_add_rounded, name: 'Note Add'),
    NotebookIcon(id: 143, icon: Icons.format_quote_rounded, name: 'Quote'),
    NotebookIcon(
      id: 144,
      icon: Icons.format_list_bulleted_rounded,
      name: 'List',
    ),
    NotebookIcon(
      id: 145,
      icon: Icons.format_list_numbered_rounded,
      name: 'Numbered List',
    ),
    NotebookIcon(
      id: 146,
      icon: Icons.format_align_left_rounded,
      name: 'Align Left',
    ),
    NotebookIcon(
      id: 147,
      icon: Icons.format_align_center_rounded,
      name: 'Align Center',
    ),
    NotebookIcon(
      id: 148,
      icon: Icons.format_align_right_rounded,
      name: 'Align Right',
    ),
    NotebookIcon(id: 149, icon: Icons.format_bold_rounded, name: 'Bold'),
    NotebookIcon(id: 150, icon: Icons.format_italic_rounded, name: 'Italic'),
    NotebookIcon(
      id: 151,
      icon: Icons.format_underline_rounded,
      name: 'Underline',
    ),
    NotebookIcon(
      id: 152,
      icon: Icons.format_strikethrough_rounded,
      name: 'Strikethrough',
    ),
    NotebookIcon(id: 153, icon: Icons.highlight_rounded, name: 'Highlight'),
    NotebookIcon(
      id: 154,
      icon: Icons.find_replace_rounded,
      name: 'Find Replace',
    ),
    NotebookIcon(id: 155, icon: Icons.spellcheck_rounded, name: 'Spellcheck'),
    NotebookIcon(id: 156, icon: Icons.translate_rounded, name: 'Translate'),

    // Gaming
    NotebookIcon(id: 157, icon: Icons.sports_esports_rounded, name: 'Gaming'),
    NotebookIcon(id: 158, icon: Icons.games_rounded, name: 'Games'),
    NotebookIcon(
      id: 159,
      icon: Icons.videogame_asset_rounded,
      name: 'Game Asset',
    ),
    NotebookIcon(id: 160, icon: Icons.extension_rounded, name: 'Extension'),
    NotebookIcon(
      id: 161,
      icon: Icons.extension_off_rounded,
      name: 'Extension Off',
    ),
    NotebookIcon(id: 162, icon: Icons.emoji_events_rounded, name: 'Trophy'),
    NotebookIcon(
      id: 163,
      icon: Icons.workspace_premium_rounded,
      name: 'Premium',
    ),
    NotebookIcon(id: 164, icon: Icons.diamond_rounded, name: 'Diamond'),
    NotebookIcon(
      id: 165,
      icon: Icons.currency_bitcoin_rounded,
      name: 'Bitcoin',
    ),
    NotebookIcon(id: 166, icon: Icons.monetization_on_rounded, name: 'Coins'),
    NotebookIcon(id: 167, icon: Icons.card_giftcard_rounded, name: 'Gift'),
    NotebookIcon(id: 168, icon: Icons.celebration_rounded, name: 'Celebration'),
    NotebookIcon(id: 169, icon: Icons.rocket_launch_rounded, name: 'Rocket'),
    NotebookIcon(id: 170, icon: Icons.flight_takeoff_rounded, name: 'Takeoff'),
    NotebookIcon(
      id: 171,
      icon: Icons.sports_martial_arts_rounded,
      name: 'Fighting',
    ),
    NotebookIcon(
      id: 172,
      icon: Icons.sports_handball_rounded,
      name: 'Handball',
    ),
    NotebookIcon(
      id: 173,
      icon: Icons.sports_volleyball_rounded,
      name: 'Volleyball',
    ),
    NotebookIcon(id: 174, icon: Icons.sports_cricket_rounded, name: 'Cricket'),
    NotebookIcon(id: 175, icon: Icons.sports_hockey_rounded, name: 'Hockey'),
    NotebookIcon(id: 176, icon: Icons.sports_golf_rounded, name: 'Golf'),
    NotebookIcon(
      id: 177,
      icon: Icons.sports_baseball_rounded,
      name: 'Baseball',
    ),
    NotebookIcon(
      id: 178,
      icon: Icons.sports_football_rounded,
      name: 'Football',
    ),
    NotebookIcon(id: 179, icon: Icons.sports_rugby_rounded, name: 'Rugby'),
    NotebookIcon(
      id: 180,
      icon: Icons.sports_motorsports_rounded,
      name: 'Racing',
    ),
    NotebookIcon(id: 181, icon: Icons.sports_kabaddi_rounded, name: 'Kabaddi'),
    NotebookIcon(id: 182, icon: Icons.sports_mma_rounded, name: 'MMA'),
    NotebookIcon(id: 183, icon: Icons.sports_score_rounded, name: 'Score'),
    NotebookIcon(id: 184, icon: Icons.timer_rounded, name: 'Timer'),
    NotebookIcon(id: 185, icon: Icons.speed_rounded, name: 'Speed'),
    NotebookIcon(
      id: 186,
      icon: Icons.trending_down_rounded,
      name: 'Level Down',
    ),
    NotebookIcon(id: 187, icon: Icons.show_chart_rounded, name: 'Stats'),
    NotebookIcon(id: 188, icon: Icons.analytics_rounded, name: 'Analytics'),
    NotebookIcon(id: 189, icon: Icons.leaderboard_rounded, name: 'Leaderboard'),
    NotebookIcon(id: 190, icon: Icons.people_alt_rounded, name: 'Multiplayer'),
    NotebookIcon(id: 191, icon: Icons.group_work_rounded, name: 'Team'),
    NotebookIcon(
      id: 192,
      icon: Icons.person_remove_rounded,
      name: 'Remove Player',
    ),
    NotebookIcon(id: 193, icon: Icons.shield_rounded, name: 'Shield'),
    NotebookIcon(id: 194, icon: Icons.lock_rounded, name: 'Lock'),
    NotebookIcon(id: 195, icon: Icons.lock_open_rounded, name: 'Unlock'),
    NotebookIcon(id: 196, icon: Icons.key_rounded, name: 'Key'),
    NotebookIcon(id: 197, icon: Icons.vpn_key_rounded, name: 'VPN Key'),
    NotebookIcon(id: 198, icon: Icons.password_rounded, name: 'Password'),
    NotebookIcon(id: 199, icon: Icons.visibility_rounded, name: 'Visibility'),
    NotebookIcon(
      id: 200,
      icon: Icons.visibility_off_rounded,
      name: 'Visibility Off',
    ),
    NotebookIcon(id: 201, icon: Icons.settings_rounded, name: 'Settings'),
    NotebookIcon(id: 202, icon: Icons.tune_rounded, name: 'Tune'),
    NotebookIcon(id: 203, icon: Icons.equalizer_rounded, name: 'Equalizer'),
    NotebookIcon(id: 204, icon: Icons.graphic_eq_rounded, name: 'Graphic EQ'),
    NotebookIcon(id: 205, icon: Icons.volume_down_rounded, name: 'Volume Down'),
    NotebookIcon(id: 206, icon: Icons.volume_off_rounded, name: 'Volume Off'),
    NotebookIcon(id: 207, icon: Icons.mic_off_rounded, name: 'Microphone Off'),
    NotebookIcon(
      id: 208,
      icon: Icons.speaker_group_rounded,
      name: 'Speaker Group',
    ),
    NotebookIcon(
      id: 209,
      icon: Icons.surround_sound_rounded,
      name: 'Surround Sound',
    ),
    NotebookIcon(id: 210, icon: Icons.network_check_rounded, name: 'Network'),
    NotebookIcon(
      id: 211,
      icon: Icons.signal_cellular_4_bar_rounded,
      name: 'Signal Cellular',
    ),
    NotebookIcon(
      id: 212,
      icon: Icons.bluetooth_connected_rounded,
      name: 'Bluetooth Connected',
    ),
    NotebookIcon(
      id: 213,
      icon: Icons.bluetooth_disabled_rounded,
      name: 'Bluetooth Disabled',
    ),
    NotebookIcon(id: 214, icon: Icons.cable_rounded, name: 'Cable'),
    NotebookIcon(
      id: 215,
      icon: Icons.battery_full_rounded,
      name: 'Battery Full',
    ),
    NotebookIcon(
      id: 216,
      icon: Icons.battery_6_bar_rounded,
      name: 'Battery 6 Bar',
    ),
    NotebookIcon(
      id: 217,
      icon: Icons.battery_4_bar_rounded,
      name: 'Battery 4 Bar',
    ),
    NotebookIcon(
      id: 218,
      icon: Icons.battery_2_bar_rounded,
      name: 'Battery 2 Bar',
    ),
    NotebookIcon(
      id: 219,
      icon: Icons.battery_0_bar_rounded,
      name: 'Battery Empty',
    ),
    NotebookIcon(id: 220, icon: Icons.arrow_circle_right_rounded, name: 'Next'),
    NotebookIcon(
      id: 221,
      icon: Icons.arrow_circle_left_rounded,
      name: 'Previous',
    ),
    NotebookIcon(id: 222, icon: Icons.work_history_rounded, name: 'Work History'),
    NotebookIcon(id: 223, icon: Icons.light_mode_rounded, name: 'Light Mode'),
    NotebookIcon(id: 224, icon: Icons.podcasts_rounded, name: 'Podcast'),
    NotebookIcon(id: 225, icon: Icons.web_rounded, name: 'Web'),
    NotebookIcon(id: 226, icon: Icons.mic_external_on_rounded, name: 'External Mic'),
    NotebookIcon(id: 227, icon: Icons.image_search_rounded, name: 'Image Search'),
    NotebookIcon(
      id: 228,
      icon: Icons.video_collection_rounded,
      name: 'Video Collection',
    ),
    NotebookIcon(id: 229, icon: Icons.video_file_rounded, name: 'Video File'),
    NotebookIcon(id: 230, icon: FontAwesomeIcons.tiktok, name: 'Tiktok'),
    NotebookIcon(id: 231, icon: FontAwesomeIcons.youtube, name: 'Youtube'),
    NotebookIcon(id: 232, icon: FontAwesomeIcons.instagram, name: 'Instagram'),
    NotebookIcon(id: 233, icon: FontAwesomeIcons.facebook, name: 'Facebook'),
    NotebookIcon(id: 234, icon: FontAwesomeIcons.xTwitter, name: 'Twitter'),
    NotebookIcon(id: 235, icon: FontAwesomeIcons.github, name: 'Github'),
    NotebookIcon(id: 236, icon: FontAwesomeIcons.google, name: 'Google'),
    NotebookIcon(id: 237, icon: FontAwesomeIcons.xbox, name: 'Xbox'),
    NotebookIcon(
      id: 238,
      icon: FontAwesomeIcons.playstation,
      name: 'Playstation',
    ),
    NotebookIcon(id: 239, icon: FontAwesomeIcons.steam, name: 'Steam'),
    NotebookIcon(id: 240, icon: FontAwesomeIcons.discord, name: 'Discord'),
    NotebookIcon(id: 241, icon: FontAwesomeIcons.bullseye, name: 'Bullseye'),
    NotebookIcon(id: 242, icon: FontAwesomeIcons.whatsapp, name: 'Whatsapp'),
    NotebookIcon(id: 243, icon: FontAwesomeIcons.reddit, name: 'Reddit'),
    NotebookIcon(id: 244, icon: FontAwesomeIcons.pinterest, name: 'Pinterest'),
    NotebookIcon(id: 245, icon: FontAwesomeIcons.book, name: 'Book'),
    NotebookIcon(id: 246, icon: Icons.coffee_rounded, name: 'Coffee'),
    NotebookIcon(id: 247, icon: Icons.newspaper_rounded, name: 'Newspaper'),
    NotebookIcon(id: 248, icon: Icons.calendar_month_rounded, name: 'Calendar'),
    NotebookIcon(id: 249, icon: Icons.calendar_today_rounded, name: 'Calendar Today'),
    NotebookIcon(id: 250, icon: Icons.alarm_rounded, name: 'Alarm'),

    ];

  static NotebookIcon? getIconById(int id) {
    try {
      return icons.firstWhere((icon) => icon.id == id);
    } catch (e) {
      return null;
    }
  }

  static NotebookIcon getDefaultIcon() {
    return icons.first; // Retorna el primer icono (folder_rounded)
  }
}
