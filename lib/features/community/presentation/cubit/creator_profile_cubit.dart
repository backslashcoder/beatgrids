import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/errors/app_failure.dart';
import '../../data/community_repository.dart';
import '../../models/public_beat.dart';

enum ProfileStatus { loading, ready, notFound, failed }

class CreatorProfileState extends Equatable {
  const CreatorProfileState({
    this.status = ProfileStatus.loading,
    this.profile,
    this.avatarUrl,
    this.error,
  });

  final ProfileStatus status;
  final CreatorProfile? profile;
  final String? avatarUrl;
  final String? error;

  @override
  List<Object?> get props => [status, profile, avatarUrl, error];
}

/// Loads a creator's public profile by username. Their beats are a separate
/// [CreatorBeatsCubit] so the list can paginate on its own.
class CreatorProfileCubit extends Cubit<CreatorProfileState> {
  CreatorProfileCubit(this._repo, this.username)
    : super(const CreatorProfileState());

  final CommunityRepository _repo;
  final String username;

  Future<void> load() async {
    emit(const CreatorProfileState());
    try {
      final profile = await _repo.creatorByUsername(username);
      if (isClosed) return;
      if (profile == null) {
        emit(const CreatorProfileState(status: ProfileStatus.notFound));
        return;
      }
      emit(
        CreatorProfileState(
          status: ProfileStatus.ready,
          profile: profile,
          avatarUrl: _repo.avatarUrl(profile.avatarPath),
        ),
      );
    } on AppFailure catch (f) {
      if (!isClosed)
        emit(
          CreatorProfileState(status: ProfileStatus.failed, error: f.message),
        );
    }
  }
}
