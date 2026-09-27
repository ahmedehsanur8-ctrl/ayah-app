import 'models/content.dart';
import 'services/rotation.dart';
import 'services/settings.dart';

/// Things the whole app needs, loaded once at start-up.
class AppState {
  AppState._(this.settings, this.data) : rotation = Rotation(data);

  static late AppState instance;

  final AppSettings settings;
  final ContentData data;
  final Rotation rotation;

  static Future<AppState> load() async {
    final settings = await AppSettings.load();
    final data = await ContentData.load();
    return instance = AppState._(settings, data);
  }
}
