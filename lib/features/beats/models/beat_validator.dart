import '../../studio/models/beat_pattern.dart';
import 'beat.dart';
import 'genres.dart';

/// Title given to beats that were never named.
const kUntitledBeat = 'Untitled beat';

enum BeatField { title, description, genre, bpm, pattern }

/// Client-side checks that mirror the database constraints, plus publish-only
/// rules. The database stays authoritative.
abstract final class BeatValidator {
  static const maxTitle = 80;
  static const maxDescription = 500;

  /// Returns field -> message; empty when valid.
  static Map<BeatField, String> validate(
    BeatInput input, {
    required bool forPublish,
  }) {
    final errors = <BeatField, String>{};
    final title = input.title.trim();
    if (title.isEmpty) {
      errors[BeatField.title] = 'Give your beat a title.';
    } else if (title.length > maxTitle) {
      errors[BeatField.title] = 'Keep the title under $maxTitle characters.';
    } else if (forPublish && title == kUntitledBeat) {
      errors[BeatField.title] = 'Name your beat before publishing.';
    }
    if ((input.description?.length ?? 0) > maxDescription) {
      errors[BeatField.description] =
          'Keep the description under $maxDescription characters.';
    }
    if (!isKnownGenre(input.genre)) {
      errors[BeatField.genre] = 'Pick a genre.';
    }
    if (input.bpm < kMinBpm || input.bpm > kMaxBpm) {
      errors[BeatField.bpm] = 'Tempo must be $kMinBpm-$kMaxBpm BPM.';
    }
    if (forPublish && input.pattern.isEmpty) {
      errors[BeatField.pattern] = 'Add some steps before publishing.';
    }
    // Round-trip through the strict parser: what we send must be what the
    // database and every player will accept.
    try {
      BeatPattern.fromJson(input.pattern.toJson());
    } on PatternFormatException {
      errors[BeatField.pattern] = 'The pattern is not valid.';
    }
    return errors;
  }
}
