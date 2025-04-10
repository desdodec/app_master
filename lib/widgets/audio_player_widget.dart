import 'dart:io';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:flutter/foundation.dart'; // For debugPrint
import '../models/track.dart';

class GlobalAudioManager {
  static AudioPlayer? currentPlayer;

  static Future<void> play(AudioPlayer player) async {
    if (currentPlayer != null && currentPlayer != player) {
      await currentPlayer!.stop();
      debugPrint('Stopped previous audio player.');
    }
    currentPlayer = player;
    await player.play();
    debugPrint('Started playing on current audio player.');
  }

  static Future<void> pause(AudioPlayer player) async {
    if (currentPlayer == player) {
      await player.pause();
      currentPlayer = null;
      debugPrint('Paused current audio player.');
    } else {
      await player.pause();
      debugPrint('Paused audio player (not the current one).');
    }
  }
}

class AudioPlayerWidget extends StatefulWidget {
  final Track track;
  const AudioPlayerWidget({Key? key, required this.track}) : super(key: key);

  @override
  State<AudioPlayerWidget> createState() => _AudioPlayerWidgetState();
}

class _AudioPlayerWidgetState extends State<AudioPlayerWidget> {
  late AudioPlayer _player;
  Duration? _duration;
  Duration _position = Duration.zero;
  bool _isPlaying = false;
  final double coverSize = 60;
  // Ideal width for waveform: 250 * 4 = 1000 pixels.
  final double waveformWidth = 250 * 4;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _initAudio();
  }

  Future<void> _initAudio() async {
    try {
      debugPrint("Loading audio from: ${widget.track.audioPath}");
      await _player.setFilePath(widget.track.audioPath);
      debugPrint("Audio file loaded from: ${widget.track.audioPath}");

      _duration = _player.duration ?? Duration(seconds: widget.track.duration);
      debugPrint("Audio duration: $_duration");

      _player.positionStream.listen((pos) {
        if (!mounted) return;
        debugPrint("Audio position updated: $pos");
        setState(() {
          _position = pos;
        });
      });
      _player.playerStateStream.listen((state) {
        if (!mounted) return;
        debugPrint("Audio player state: playing = ${state.playing}");
        setState(() {
          _isPlaying = state.playing;
        });
      });
    } catch (e) {
      debugPrint("Error initializing audio: $e");
    }
  }

  Future<void> _togglePlayPause() async {
    if (_isPlaying) {
      debugPrint("Pausing audio: ${widget.track.audioPath}");
      await GlobalAudioManager.pause(_player);
    } else {
      debugPrint("Playing audio file: ${widget.track.audioPath}");
      if (_position >= (_duration ?? Duration.zero)) {
        debugPrint("Restarting audio from beginning.");
        await _player.seek(Duration.zero);
      }
      await GlobalAudioManager.play(_player);
    }
  }

  Future<void> _onWaveformTap(TapDownDetails details) async {
    final tapX = details.localPosition.dx;
    if (_duration == null || _duration!.inMilliseconds == 0) {
      await GlobalAudioManager.play(_player);
      return;
    }
    final tapFraction = tapX / waveformWidth;
    final seekPosition = _duration! * tapFraction;
    debugPrint('Waveform tap: seeking to $seekPosition (tap position: $tapX)');
    await _player.seek(seekPosition);
    if (!_isPlaying) {
      await GlobalAudioManager.play(_player);
    }
  }

  Widget _buildAlbumCover() {
    final file = File(widget.track.artworkPath);
    if (file.existsSync()) {
      return Image.file(
        file,
        width: coverSize,
        height: coverSize,
        fit: BoxFit.cover,
      );
    } else {
      return Container(
        width: coverSize,
        height: coverSize,
        color: Colors.grey,
        child: Icon(
          Icons.music_note,
          size: coverSize * 0.6,
          color: Colors.white,
        ),
      );
    }
  }

  /// Builds the waveform widget wrapped in a SingleChildScrollView so that if the
  /// fixed width (ideal 1000 pixels) is larger than available space, it allows horizontal scrolling.
  Widget _buildWaveform() {
    double progressFraction = 0.0;
    if (_duration != null && _duration!.inMilliseconds > 0) {
      progressFraction = _position.inMilliseconds / _duration!.inMilliseconds;
      progressFraction = progressFraction.clamp(0.0, 1.0);
    }
    final overlayWidth = waveformWidth * progressFraction;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Container(
        width: waveformWidth,
        height: coverSize,
        color: Colors.black12,
        child: Stack(
          children: [
            Image.file(
              File(widget.track.waveformPath),
              width: waveformWidth,
              height: coverSize,
              fit: BoxFit.fill,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  width: waveformWidth,
                  height: coverSize,
                  color: Colors.blueGrey,
                  child: Center(
                    child: Text("Waveform", style: TextStyle(fontSize: 12)),
                  ),
                );
              },
            ),
            ClipRect(
              clipper: _WaveformClipper(overlayWidth),
              child: Image.file(
                File(widget.track.waveformOverlayPath),
                width: waveformWidth,
                height: coverSize,
                fit: BoxFit.fill,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: waveformWidth,
                    height: coverSize,
                    color: Colors.transparent,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    return "${twoDigits(d.inMinutes)}:${twoDigits(d.inSeconds.remainder(60))}";
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _buildAlbumCover(),
        IconButton(
          icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
          onPressed: _togglePlayPause,
        ),
        // The waveform widget is wrapped in an Expanded to let it use available space,
        // but its internal SingleChildScrollView will let the user scroll horizontally.
        Expanded(child: _buildWaveform()),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Text(
            _duration != null
                ? "${_formatDuration(_position)} / ${_formatDuration(_duration!)}"
                : "Loading...",
            style: TextStyle(fontSize: 12),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }
}

class _WaveformClipper extends CustomClipper<Rect> {
  final double clipWidth;
  _WaveformClipper(this.clipWidth);

  @override
  Rect getClip(Size size) => Rect.fromLTWH(0, 0, clipWidth, size.height);

  @override
  bool shouldReclip(_WaveformClipper oldClipper) =>
      clipWidth != oldClipper.clipWidth;
}
