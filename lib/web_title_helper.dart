import 'dart:html' as html;

import 'global_constants.dart'; // Import HTML for web title updates

class WebTitleHelper {
  static String defaultTitle = GlobalConstants.version + GlobalConstants.defaultTitle;

  /// Updates the web title
  static void updateTitle(String title) {
    html.document.title = title;
  }

  /// Resets the title to the default value
  static void resetTitle() {
    html.document.title = defaultTitle;
  }
}
