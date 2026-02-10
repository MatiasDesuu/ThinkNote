import 'package:intl/intl.dart';
import 'dart:io';

class TemplateVariableProcessor {
  static String process(
    String text, {
    String? notebookName,
    List<String>? existingTitles,
  }) {
    final now = DateTime.now();

    String processed = text;

    if (processed.contains('{{number}}') && existingTitles != null) {
      String baseTemplate = processed.replaceAll('{{number}}', '');
      String processedBase = process(baseTemplate, notebookName: notebookName);
      int count =
          existingTitles
              .where((title) => title.startsWith(processedBase))
              .length;
      String number = (count + 1).toString();
      processed = processed.replaceAll('{{number}}', number);
    }

    processed = processed.replaceAll(
      '{{date}}',
      DateFormat('yyyy/MM/dd').format(now),
    );
    processed = processed.replaceAll('{{day}}', DateFormat('dd').format(now));
    processed = processed.replaceAll('{{month}}', DateFormat('MM').format(now));
    processed = processed.replaceAll(
      '{{monthname}}',
      DateFormat('MMMM').format(now),
    );
    processed = processed.replaceAll(
      '{{monthnameshort}}',
      DateFormat('MMM').format(now),
    );
    processed = processed.replaceAll(
      '{{year}}',
      DateFormat('yyyy').format(now),
    );
    processed = processed.replaceAll(
      '{{time}}',
      DateFormat('HH:mm').format(now),
    );
    processed = processed.replaceAll(
      '{{time12}}',
      DateFormat('hh:mm a').format(now),
    );
    processed = processed.replaceAll(
      '{{weekday}}',
      DateFormat('EEEE').format(now),
    );
    processed = processed.replaceAll(
      '{{weekdayshort}}',
      DateFormat('EEE').format(now),
    );
    processed = processed.replaceAll('{{week}}', DateFormat('w').format(now));
    processed = processed.replaceAll(
      '{{dayofyear}}',
      DateFormat('D').format(now),
    );

    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final endOfWeek = startOfWeek.add(Duration(days: 6));

    processed = processed.replaceAll(
      '{{weekstart}}',
      DateFormat('yyyy/MM/dd').format(startOfWeek),
    );
    processed = processed.replaceAll(
      '{{weekend}}',
      DateFormat('yyyy/MM/dd').format(endOfWeek),
    );

    processed = processed.replaceAll(
      '{{tomorrow}}',
      DateFormat('yyyy/MM/dd').format(now.add(Duration(days: 1))),
    );
    processed = processed.replaceAll(
      '{{yesterday}}',
      DateFormat('yyyy/MM/dd').format(now.subtract(Duration(days: 1))),
    );

    processed = processed.replaceAll(
      '{{dateiso}}',
      DateFormat('yyyy-MM-dd').format(now),
    );
    processed = processed.replaceAll(
      '{{datelong}}',
      DateFormat('EEEE, d MMMM yyyy').format(now),
    );
    processed = processed.replaceAll(
      '{{dateshort}}',
      DateFormat('dd/MM').format(now),
    );

    processed = processed.replaceAll(
      '{{created}}',
      DateFormat('yyyy/MM/dd HH:mm').format(now),
    );

    processed = processed.replaceAll('{{hour}}', DateFormat('HH').format(now));
    processed = processed.replaceAll(
      '{{minute}}',
      DateFormat('mm').format(now),
    );
    processed = processed.replaceAll('{{ampm}}', DateFormat('a').format(now));
    processed = processed.replaceAll(
      '{{timestamp}}',
      now.millisecondsSinceEpoch.toString(),
    );
    processed = processed.replaceAll('{{timezone}}', now.timeZoneName);

    String greeting;
    final hour = now.hour;
    if (hour >= 5 && hour < 12) {
      greeting = 'Good morning';
    } else if (hour >= 12 && hour < 18) {
      greeting = 'Good afternoon';
    } else {
      greeting = 'Good evening';
    }
    processed = processed.replaceAll('{{greeting}}', greeting);

    String platform = 'Unknown';
    if (Platform.isAndroid) {
      platform = 'Android';
    } else if (Platform.isIOS) {
      platform = 'iOS';
    } else if (Platform.isWindows) {
      platform = 'Windows';
    } else if (Platform.isMacOS) {
      platform = 'macOS';
    } else if (Platform.isLinux) {
      platform = 'Linux';
    }
    processed = processed.replaceAll('{{platform}}', platform);

    if (notebookName != null) {
      processed = processed.replaceAll('{{notebook}}', notebookName);
    }

    return processed;
  }
}
