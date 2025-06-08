/*
 * Guardian - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * Contact: kunalsingh2514@gmail.com
 */

import 'package:flutter_test/flutter_test.dart';

// Core Utils
import 'core/utils/location_utils_test.dart' as location_utils_test;
import 'core/utils/logger_util_test.dart' as logger_util_test;
import 'core/utils/animation_utils_test.dart' as animation_utils_test;
import 'core/utils/api_keys_test.dart' as api_keys_test;
import 'core/utils/permission_utils_test.dart' as permission_utils_test;
import 'core/utils/string_utils_test.dart' as string_utils_test;
import 'core/utils/date_utils_test.dart' as date_utils_test;
import 'core/utils/validation_utils_test.dart' as validation_utils_test;
import 'core/utils/network_utils_test.dart' as network_utils_test;

// Core Services
import 'core/services/maps_service_test.dart' as maps_service_test;
import 'core/services/location_service_test.dart' as location_service_test;

// Core Widgets
import 'core/widgets/custom_button_test.dart' as custom_button_test;
import 'core/widgets/custom_text_field_test.dart' as custom_text_field_test;
import 'core/widgets/custom_app_bar_test.dart' as custom_app_bar_test;
import 'core/widgets/loading_indicator_test.dart' as loading_indicator_test;
import 'core/widgets/error_display_test.dart' as error_display_test;

// Features
import 'features/auth/auth_repository_test.dart' as auth_repository_test;
import 'features/splash/splash_screen_test.dart' as splash_screen_test;

// Widget Tests
import 'widget_test.dart' as widget_test;

void main() {
  group('All Tests', () {
    group('Core Utils', () {
      location_utils_test.main();
      logger_util_test.main();
      animation_utils_test.main();
      api_keys_test.main();
      permission_utils_test.main();
      string_utils_test.main();
      date_utils_test.main();
      validation_utils_test.main();
      network_utils_test.main();
    });

    group('Core Services', () {
      maps_service_test.main();
      location_service_test.main();
    });

    group('Core Widgets', () {
      custom_button_test.main();
      custom_text_field_test.main();
      custom_app_bar_test.main();
      loading_indicator_test.main();
      error_display_test.main();
    });

    group('Features', () {
      group('Auth', () {
        auth_repository_test.main();
      });

      group('Splash', () {
        splash_screen_test.main();
      });
    });

    group('Widget Tests', () {
      widget_test.main();
    });
  });
}
