import '../services/audio_service.dart';
import '../services/synth.dart';

const _pentMajor = [0, 2, 4, 7, 9];
const _lydian = [0, 2, 4, 6, 7, 9, 11];
const _dorian = [0, 2, 3, 5, 7, 9, 10];
const _dream = [0, 2, 4, 7, 9, 11];

/// One track per world + menu/bonus/daily. Replace any of them with a real
/// file by giving it an `assetPath` (put the file in assets/audio/).
List<MusicTrack> defaultTracks() => const [
      MusicTrack('menu', synth: SongSpec(bpm: 88, root: 60, scale: _pentMajor, seed: 11, density: 0.55)),
      MusicTrack('world_0', synth: SongSpec(bpm: 76, root: 62, scale: _pentMajor, seed: 21, density: 0.45)),
      MusicTrack('world_1', synth: SongSpec(bpm: 104, root: 65, scale: _pentMajor, seed: 22, density: 0.65)),
      MusicTrack('world_2', synth: SongSpec(bpm: 96, root: 60, scale: _pentMajor, seed: 23, density: 0.6)),
      MusicTrack('world_3', synth: SongSpec(bpm: 112, root: 67, scale: _pentMajor, seed: 24, density: 0.7)),
      MusicTrack('world_4', synth: SongSpec(bpm: 100, root: 64, scale: _pentMajor, seed: 25, density: 0.6)),
      MusicTrack('world_5', synth: SongSpec(bpm: 108, root: 62, scale: _lydian, seed: 26, density: 0.6)),
      MusicTrack('world_6', synth: SongSpec(bpm: 96, root: 57, scale: _dorian, seed: 27, density: 0.6)),
      MusicTrack('world_7', synth: SongSpec(bpm: 80, root: 59, scale: _lydian, seed: 28, density: 0.5)),
      MusicTrack('world_8', synth: SongSpec(bpm: 84, root: 57, scale: _dream, seed: 29, density: 0.5)),
      MusicTrack('world_9', synth: SongSpec(bpm: 90, root: 55, scale: _dorian, seed: 30, density: 0.55)),
      MusicTrack('bonus', synth: SongSpec(bpm: 118, root: 64, scale: _pentMajor, seed: 41, density: 0.75)),
      MusicTrack('daily', synth: SongSpec(bpm: 110, root: 67, scale: _lydian, seed: 42, density: 0.7)),
    ];
