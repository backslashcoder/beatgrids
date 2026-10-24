import 'package:equatable/equatable.dart';

class UserProfile extends Equatable {
  const UserProfile({
    required this.id,
    required this.username,
    required this.displayName,
    required this.createdAt,
    this.bio,
    this.avatarPath,
  });

  final String id;
  final String username;
  final String displayName;
  final String? bio;

  /// Storage path inside the `avatars` bucket, or null for the default avatar.
  final String? avatarPath;
  final DateTime createdAt;

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
    id: json['id'] as String,
    username: json['username'] as String,
    displayName: json['display_name'] as String,
    bio: json['bio'] as String?,
    avatarPath: json['avatar_path'] as String?,
    createdAt: DateTime.parse(json['created_at'] as String),
  );

  @override
  List<Object?> get props => [
    id,
    username,
    displayName,
    bio,
    avatarPath,
    createdAt,
  ];
}
