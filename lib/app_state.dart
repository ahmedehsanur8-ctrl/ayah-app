import 'models/content.dart';
import 'models/story.dart';
import 'services/rotation.dart';
import 'services/settings.dart';

/// Things the whole app needs, loaded once at start-up.
class AppState {
  AppState._(this.settings, this.data, this.stories) : rotation = Rotation(data);

  static late AppState instance;

  final AppSettings settings;
  final ContentData data;
  final Rotation rotation;
  final List<Story> stories;

  static Future<AppState> load() async {
    final settings = await AppSettings.load();
    final data = await ContentData.load();
    final stories = await Story.load();
    return instance = AppState._(settings, data, stories);
  }
}
