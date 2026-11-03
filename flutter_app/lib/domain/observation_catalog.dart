import 'models.dart';

const observationTones = {
  'positive': 'Positiv',
  'neutral': 'Neutral',
  'negative': 'Negativ',
};
const observationSigns = {'positive': '+', 'neutral': '•', 'negative': '−'};

const observationDefaults = <String, List<String>>{
  'social-positive': [
    'Hilft anderen',
    'Nimmt Hilfe an',
    'Hält Gesprächsregeln ein',
    'Geht respektvoll mit anderen um',
    'Klärt einen Konflikt im Gespräch',
    'Hält gemeinsame Absprachen ein',
  ],
  'social-neutral': [
    'Beteiligt sich am Gespräch',
    'Stellt eine Frage',
    'Berichtet von einem Erlebnis',
    'Beobachtet die Gruppe',
    'Wählt eine Gruppenrolle',
  ],
  'social-negative': [
    'Unterbricht andere wiederholt',
    'Spricht andere abwertend an',
    'Hält gemeinsame Absprachen nicht ein',
    'Stört die Zusammenarbeit',
  ],
  'work-positive': [
    'Beginnt selbstständig',
    'Arbeitet konzentriert',
    'Bleibt bei Schwierigkeiten dran',
    'Fragt gezielt nach Hilfe',
    'Schließt die Aufgabe ab',
    'Arbeitet sorgfältig',
  ],
  'work-neutral': [
    'Arbeitet an der Aufgabe',
    'Liest die Aufgabenstellung',
    'Nutzt Arbeitsmaterial',
    'Bespricht einen Arbeitsschritt',
    'Wechselt die Arbeitsform',
  ],
  'work-negative': [
    'Beginnt erst nach mehreren Aufforderungen',
    'Beschäftigt sich wiederholt mit anderem',
    'Unterbricht die Arbeit vorzeitig',
    'Bearbeitet die vereinbarte Aufgabe nicht',
    'Lässt vereinbarte Arbeitsschritte aus',
  ],
};

class ObservationCatalog {
  ObservationCatalog({
    required List<String> options,
    List<String> favorites = const [],
  }) : options = List.unmodifiable(options),
       favorites = List.unmodifiable(favorites);
  final List<String> options, favorites;
  factory ObservationCatalog.defaults(String key) => ObservationCatalog(
    options:
        observationDefaults[key] ??
        (throw const DomainError('Unbekannter Beobachtungsbereich.')),
  );
  Json toJson() => {'version': 1, 'options': options, 'favorites': favorites};
  factory ObservationCatalog.fromJson(Json json) {
    final options = json['options'], favorites = json['favorites'];
    bool valid(dynamic values) =>
        values is List &&
        values.length <= 200 &&
        values.every(
          (v) => v is String && v.trim().isNotEmpty && v.length <= 200,
        ) &&
        values.toSet().length == values.length;
    if (json['version'] != 1 ||
        !valid(options) ||
        !valid(favorites) ||
        !(favorites as List).every((v) => (options as List).contains(v))) {
      throw const DomainError('Ungültige Beobachtungsauswahl.');
    }
    return ObservationCatalog(
      options: List<String>.from(options as List),
      favorites: List<String>.from(favorites),
    );
  }
}
