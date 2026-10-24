import 'dart:async';
import 'dart:typed_data';

import 'package:beatgrid/core/errors/app_failure.dart';
import 'package:beatgrid/features/beats/data/pending_draft_store.dart';
import 'package:beatgrid/features/beats/models/beat.dart';
import 'package:beatgrid/features/beats/models/beat_validator.dart';
import 'package:beatgrid/features/beats/presentation/cubit/beat_editor_cubit.dart';
import 'package:beatgrid/features/studio/models/beat_pattern.dart';
import 'package:beatgrid/features/studio/models/starter_patterns.dart';
import 'package:beatgrid/features/studio/presentation/cubit/studio_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fakes/fake_audio_engine.dart';
import 'fakes/fake_beat_repository.dart';

Future<void> flush() => Future<void>.delayed(Duration.zero);

class Harness {
  Harness({String? userId = 'u1'}) : repo = FakeBeatRepository(userId: userId) {
    engine = FakeAudioEngine();
    studio = StudioCubit(engine);
    editor = BeatEditorCubit(repo, studio);
  }

  final FakeBeatRepository repo;
  late final FakeAudioEngine engine;
  late final StudioCubit studio;
  late final BeatEditorCubit editor;

  /// Gives the studio some steps, like a user would.
  void makeBeat() {
    studio.toggleStep(TrackId.kick, 0);
    studio.toggleStep(TrackId.snare, 4);
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('dirty tracking', () {
    test('a fresh studio has nothing to lose', () {
      expect(Harness().editor.state.dirty, isFalse);
    });

    test('editing steps, tempo or metadata makes it dirty; undoing back to saved does not', () async {
      final h = Harness();
      h.studio.toggleStep(TrackId.kick, 0);
      await flush();
      expect(h.editor.state.dirty, isTrue);
      h.studio.undo();
      await flush();
      expect(h.editor.state.dirty, isFalse);
      h.studio.setBpm(99);
      await flush();
      expect(h.editor.state.dirty, isTrue);
      h.studio.setBpm(120);
      await flush();
      expect(h.editor.state.dirty, isFalse);
      h.editor.setTitle('Hello');
      expect(h.editor.state.dirty, isTrue);
      h.editor.setTitle('');
      expect(h.editor.state.dirty, isFalse);
    });

    test('playback progress alone never marks the beat dirty', () async {
      final h = Harness();
      await h.studio.play();
      for (var i = 0; i < 16; i++) {
        h.engine.emitStep(i);
      }
      await flush();
      expect(h.editor.state.dirty, isFalse);
    });

    test('genre follows a loaded starter until the user picks one', () async {
      final h = Harness();
      h.studio.loadStarter(starterById('techno-pulse')!);
      await flush();
      expect(h.editor.state.genre, 'techno');
      h.editor.setGenre('lo-fi');
      h.studio.loadStarter(starterById('trap-starter')!);
      await flush();
      expect(h.editor.state.genre, 'lo-fi');
    });
  });

  group('saving drafts', () {
    test('first save creates a private draft, later saves update it', () async {
      final h = Harness()..makeBeat();
      await flush();
      expect(await h.editor.save(), isTrue);
      final s = h.editor.state;
      expect(s.beatId, isNotNull);
      expect(s.status, BeatStatus.draft);
      expect(s.title, kUntitledBeat);
      expect(s.dirty, isFalse);
      expect(h.repo.calls, contains('create'));
      final stored = h.repo.beats[s.beatId]!;
      expect(stored.pattern.isActive(TrackId.snare, 4), isTrue);
      expect(stored.isPublished, isFalse);

      h.studio.toggleStep(TrackId.clap, 12);
      await flush();
      expect(h.editor.state.dirty, isTrue);
      expect(await h.editor.save(), isTrue);
      expect(h.repo.calls.where((c) => c == 'create').length, 1);
      expect(h.repo.calls, contains('update'));
      expect(
        h.repo.beats[s.beatId]!.pattern.isActive(TrackId.clap, 12),
        isTrue,
      );
    });

    test('an empty untitled beat can still be saved as a draft', () async {
      final h = Harness();
      expect(await h.editor.save(), isTrue);
      expect(h.editor.state.isSaved, isTrue);
    });

    test(
      'a failed save keeps the work, reports the error and stays dirty',
      () async {
        final h = Harness()..makeBeat();
        await flush();
        h.repo.failNext = const AppFailure(
          'Could not reach BeatGrid.',
          code: 'network',
        );
        expect(await h.editor.save(), isFalse);
        expect(h.editor.state.error, 'Could not reach BeatGrid.');
        expect(h.editor.state.busy, EditorBusy.none);
        expect(h.editor.state.isSaved, isFalse);
        expect(h.editor.state.dirty, isTrue);
        expect(await h.editor.save(), isTrue, reason: 'retry works');
      },
    );

    test('double submit is ignored while saving', () async {
      final h = Harness()..makeBeat();
      await flush();
      final gate = Completer<void>();
      h.repo.gate = gate;
      final first = h.editor.save();
      await flush();
      expect(h.editor.state.busy, EditorBusy.saving);
      expect(await h.editor.save(), isFalse);
      expect(await h.editor.publish(), isFalse);
      gate.complete();
      expect(await first, isTrue);
      expect(h.repo.calls.where((c) => c == 'create').length, 1);
    });

    test('edits made while the save is in flight remain unsaved', () async {
      final h = Harness()..makeBeat();
      await flush();
      final gate = Completer<void>();
      h.repo.gate = gate;
      final saving = h.editor.save();
      await flush();
      h.studio.toggleStep(TrackId.clap, 8);
      await flush();
      gate.complete();
      await saving;
      expect(h.editor.state.dirty, isTrue);
    });
  });

  group('publishing', () {
    test(
      'requires steps and a real title and sends nothing when invalid',
      () async {
        final h = Harness();
        expect(await h.editor.publish(), isFalse);
        expect(
          h.editor.state.fieldErrors.keys,
          containsAll([BeatField.title, BeatField.pattern]),
        );
        expect(h.repo.calls, isEmpty);
        h.makeBeat();
        expect(await h.editor.publish(), isFalse, reason: 'still untitled');
        h.editor.setTitle('Night Drive');
        expect(
          h.editor.state.fieldErrors.containsKey(BeatField.title),
          isFalse,
          reason: 'editing clears the error',
        );
        expect(await h.editor.publish(), isTrue);
      },
    );

    test(
      'persists the published state with the current content in one write',
      () async {
        final h = Harness()..makeBeat();
        h.editor
          ..setTitle('Night Drive')
          ..setDescription('Late hours')
          ..setGenre('house')
          ..setAllowRemix(true);
        h.studio.setBpm(124);
        await flush();
        expect(await h.editor.publish(), isTrue);
        expect(h.repo.calls, ['create']);
        final stored = h.repo.beats.values.single;
        expect(stored.isPublished, isTrue);
        expect(stored.title, 'Night Drive');
        expect(stored.bpm, 124);
        expect(stored.allowRemix, isTrue);
        expect(stored.description, 'Late hours');
        expect(h.editor.state.isPublished, isTrue);
        expect(h.editor.state.dirty, isFalse);
      },
    );

    test(
      'publishing an existing draft updates it rather than duplicating',
      () async {
        final h = Harness()..makeBeat();
        h.editor.setTitle('Night Drive');
        await flush();
        await h.editor.save();
        expect(await h.editor.publish(), isTrue);
        expect(h.repo.beats.length, 1);
        expect(h.repo.calls, ['create', 'update']);
      },
    );

    test('server rejection (RLS) is shown, not swallowed', () async {
      final h = Harness()..makeBeat();
      h.editor.setTitle('Night Drive');
      await flush();
      await h.editor.save();
      h.repo.userId = 'someone-else'; // ownership lost
      expect(await h.editor.publish(), isFalse);
      expect(h.editor.state.error, contains('not yours'));
      expect(h.editor.state.isPublished, isFalse);
    });

    test('unpublish returns the beat to drafts and keeps edits', () async {
      final h = Harness()..makeBeat();
      h.editor.setTitle('Night Drive');
      await flush();
      await h.editor.publish();
      h.studio.toggleStep(TrackId.clap, 12);
      await flush();
      expect(await h.editor.unpublish(), isTrue);
      final stored = h.repo.beats.values.single;
      expect(stored.status, BeatStatus.draft);
      expect(stored.publishedAt, isNull);
      expect(stored.pattern.isActive(TrackId.clap, 12), isTrue);
      expect(h.editor.state.status, BeatStatus.draft);
      expect(h.editor.state.dirty, isFalse);
    });

    test('unpublish of an unsaved beat does nothing', () async {
      final h = Harness();
      expect(await h.editor.unpublish(), isFalse);
      expect(h.repo.calls, isEmpty);
    });
  });

  group('opening a saved beat', () {
    test(
      'loads pattern, tempo and metadata into the studio without dirtying it',
      () async {
        final h = Harness();
        final pattern = starterById('boom-bap')!.toPattern();
        final saved = h.repo.seed(
          input: BeatInput(
            title: 'Dusty',
            genre: 'boom-bap',
            bpm: 88,
            pattern: pattern,
            status: BeatStatus.draft,
            description: 'old',
            allowRemix: true,
          ),
        );
        await h.editor.load(saved.id);
        expect(h.editor.state.load, EditorLoad.ready);
        expect(h.editor.state.title, 'Dusty');
        expect(h.editor.state.allowRemix, isTrue);
        expect(h.editor.state.beatId, saved.id);
        expect(h.studio.state.bpm, 88);
        expect(h.studio.state.pattern.toEngineJson(), pattern.toEngineJson());
        expect(h.editor.state.dirty, isFalse);
        expect(h.studio.state.canUndo, isFalse);
      },
    );

    test('someone else\'s draft is invisible: reported as not found', () async {
      final h = Harness();
      final other = h.repo.seed(creator: 'u2', input: _input());
      await h.editor.load(other.id);
      expect(h.editor.state.load, EditorLoad.notFound);
    });

    test('someone else\'s published beat opens read-only: forbidden', () async {
      final h = Harness();
      final other = h.repo.seed(
        creator: 'u2',
        status: BeatStatus.published,
        input: _input(),
      );
      await h.editor.load(other.id);
      expect(h.editor.state.load, EditorLoad.forbidden);
      expect(
        h.studio.state.pattern.isEmpty,
        isTrue,
        reason: 'nothing leaked into the studio',
      );
    });

    test(
      'missing beats and network failures are distinct, and retry recovers',
      () async {
        final h = Harness();
        await h.editor.load('nope');
        expect(h.editor.state.load, EditorLoad.notFound);
        final saved = h.repo.seed(input: _input());
        h.repo.failNext = const AppFailure('Could not reach BeatGrid.');
        await h.editor.load(saved.id);
        expect(h.editor.state.load, EditorLoad.failed);
        expect(h.editor.state.loadError, 'Could not reach BeatGrid.');
        await h.editor.retryLoad();
        expect(h.editor.state.load, EditorLoad.ready);
      },
    );

    test('saving an opened beat updates it in place', () async {
      final h = Harness();
      final saved = h.repo.seed(input: _input());
      await h.editor.load(saved.id);
      h.studio.toggleStep(TrackId.openHat, 15);
      await flush();
      expect(await h.editor.save(), isTrue);
      expect(h.repo.calls, isNot(contains('create')));
      expect(
        h.repo.beats[saved.id]!.pattern.isActive(TrackId.openHat, 15),
        isTrue,
      );
    });

    test('startNew clears the editor', () async {
      final h = Harness();
      final saved = h.repo.seed(input: _input());
      await h.editor.load(saved.id);
      h.editor.startNew();
      expect(h.editor.state.isSaved, isFalse);
      expect(h.editor.state.title, '');
      expect(h.editor.state.dirty, isFalse);
    });
  });

  group('deleting', () {
    test('removes the beat and its saved cover', () async {
      final h = Harness();
      final saved = h.repo.seed(input: _input(), coverPath: 'u1/c.png');
      await h.editor.load(saved.id);
      expect(await h.editor.delete(), isTrue);
      expect(h.repo.beats, isEmpty);
      expect(h.repo.removedCovers, contains('u1/c.png'));
      expect(h.editor.state.deleted, isTrue);
      expect(h.editor.state.dirty, isFalse);
    });

    test('a failed delete leaves everything in place', () async {
      final h = Harness();
      final saved = h.repo.seed(input: _input());
      await h.editor.load(saved.id);
      h.repo.failNext = const AppFailure('Nope.');
      expect(await h.editor.delete(), isFalse);
      expect(h.repo.beats, isNotEmpty);
      expect(h.editor.state.deleted, isFalse);
      expect(h.editor.state.error, 'Nope.');
    });

    test('an unsaved beat cannot be deleted', () async {
      expect(await Harness().editor.delete(), isFalse);
    });
  });

  group('cover art', () {
    final bytes = Uint8List.fromList([1, 2, 3]);

    test(
      'uploading sets the path and marks the beat dirty; saving stores it',
      () async {
        final h = Harness()..makeBeat();
        h.editor.setTitle('Night Drive');
        await flush();
        expect(await h.editor.setCover(bytes, 'png'), isTrue);
        expect(h.editor.state.coverPath, 'u1/cover-0.png');
        expect(h.editor.state.coverUrl, isNotNull);
        expect(h.editor.state.dirty, isTrue);
        await h.editor.save();
        expect(h.repo.beats.values.single.coverPath, 'u1/cover-0.png');
        expect(h.repo.removedCovers, isEmpty);
      },
    );

    test('replacing an unsaved upload cleans up the first file', () async {
      final h = Harness();
      await h.editor.setCover(bytes, 'png');
      await h.editor.setCover(bytes, 'jpg');
      await flush();
      expect(h.repo.removedCovers, ['u1/cover-0.png']);
      expect(h.editor.state.coverPath, 'u1/cover-1.jpg');
    });

    test('replacing a saved cover removes the old file only after the save succeeds', () async {
      final h = Harness();
      final saved = h.repo.seed(input: _input(), coverPath: 'u1/old.png');
      await h.editor.load(saved.id);
      await h.editor.setCover(bytes, 'webp');
      expect(h.repo.removedCovers, isEmpty);
      await h.editor.save();
      expect(h.repo.removedCovers, ['u1/old.png']);
    });

    test('abandoned uploads are removed when the editor closes', () async {
      final h = Harness();
      await h.editor.setCover(bytes, 'png');
      await h.editor.close();
      await flush();
      expect(h.repo.removedCovers, ['u1/cover-0.png']);
    });

    test('upload failure is reported and leaves the cover unchanged', () async {
      final h = Harness();
      h.repo.failNext = const AppFailure('Cover art must be 5 MB or smaller.');
      expect(await h.editor.setCover(bytes, 'png'), isFalse);
      expect(h.editor.state.error, 'Cover art must be 5 MB or smaller.');
      expect(h.editor.state.coverPath, isNull);
      expect(h.editor.state.busy, EditorBusy.none);
    });

    test('removing the cover marks dirty', () async {
      final h = Harness();
      final saved = h.repo.seed(input: _input(), coverPath: 'u1/old.png');
      await h.editor.load(saved.id);
      h.editor.removeCover();
      expect(h.editor.state.coverPath, isNull);
      expect(h.editor.state.dirty, isTrue);
    });
  });

  group('pending draft (sign-in round trip)', () {
    test('stashes the beat and restores it, once', () async {
      final h = Harness()..makeBeat();
      h.editor
        ..setTitle('Before login')
        ..setAllowRemix(true);
      h.studio.setBpm(101);
      await flush();
      await h.editor.stashForSignIn();

      final fresh = Harness();
      expect(await fresh.editor.restorePending(), isTrue);
      expect(fresh.editor.state.title, 'Before login');
      expect(fresh.editor.state.allowRemix, isTrue);
      expect(fresh.studio.state.bpm, 101);
      expect(fresh.studio.state.pattern.isActive(TrackId.snare, 4), isTrue);
      expect(fresh.editor.state.dirty, isTrue, reason: 'still unsaved');
      expect(
        await Harness().editor.restorePending(),
        isFalse,
        reason: 'consumed',
      );
    });

    test('corrupt stored data is discarded safely', () async {
      SharedPreferences.setMockInitialValues({
        'beatgrid.pending_draft.v1': '{not json',
      });
      expect(await const PendingDraftStore().load(), isNull);
      expect(await Harness().editor.restorePending(), isFalse);
    });
  });
}

BeatInput _input() => BeatInput(
  title: 'Seed',
  genre: 'house',
  bpm: 120,
  pattern: starterById('house-groove')!.toPattern(),
  status: BeatStatus.draft,
);
