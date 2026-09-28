import 'content.dart';

/// A topic in বিষয়: one ayah category and (when there is one) the matching
/// hadith theme, shown together.
class Topic {
  const Topic(this.id, this.name, this.ayahCats, this.hadithThemes);

  final String id;
  final String name;
  final List<String> ayahCats;
  final List<String> hadithThemes;

  /// Ayahs first, then hadiths.
  List<ContentItem> items(ContentData data) => [
    for (final c in ayahCats) ...data.itemsIn(c),
    for (final h in hadithThemes) ...data.itemsIn(h),
  ];
}

class TopicGroup {
  const TopicGroup(this.name, this.topics);

  final String name;
  final List<Topic> topics;
}

/// The three groups of topics. Every ayah category (A1–A20) and hadith theme
/// (H1–H12) from the content list appears exactly once.
const topicGroups = [
  TopicGroup('মনের অবস্থা', [
    Topic('A1', 'আশা ও রহমত', ['A1'], ['H2']),
    Topic('A2', 'সবর', ['A2'], ['H3']),
    Topic('A3', 'তাওয়াক্কুল', ['A3'], ['H4']),
    Topic('A4', 'অন্তরের প্রশান্তি', ['A4'], ['H7']),
    Topic('A9', 'দুঃখে সান্ত্বনা', ['A9'], []),
    Topic('A11', 'দুশ্চিন্তা ও ভয়', ['A11'], []),
    Topic('A8', 'শুকরিয়া', ['A8'], ['H9']),
    Topic('H1', 'নিয়ত ও অন্তর', [], ['H1']),
  ]),
  TopicGroup('জীবন ও আমল', [
    Topic('A10', 'জীবনের উদ্দেশ্য', ['A10'], []),
    Topic('A6', 'চেষ্টা ও পরিশ্রম', ['A6'], ['H8']),
    Topic('A12', 'রিজিক ও হালাল উপার্জন', ['A12'], []),
    Topic('A13', 'উত্তম চরিত্র', ['A13'], ['H10']),
    Topic('A14', 'বাবা-মা ও পরিবার', ['A14'], ['H11']),
    Topic('A15', 'জ্ঞান', ['A15'], []),
    Topic('A19', 'বিনয় ও আত্মমর্যাদা', ['A19'], []),
    Topic('A20', 'সততা ও আমানত', ['A20'], []),
  ]),
  TopicGroup('ইবাদত ও আখিরাত', [
    Topic('A5', 'দোয়া', ['A5'], ['H6']),
    Topic('A7', 'তওবা', ['A7'], ['H5']),
    Topic('A18', 'নামাজ', ['A18'], []),
    Topic('A16', 'সময় ও আখিরাত', ['A16'], ['H12']),
    Topic('A17', 'জান্নাতের আশা', ['A17'], []),
  ]),
];
