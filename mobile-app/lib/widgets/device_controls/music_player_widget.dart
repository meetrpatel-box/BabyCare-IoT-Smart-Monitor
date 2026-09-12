import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/mqtt_provider.dart';
import '../../models/audio_track.dart';

/// Widget for controlling music playback on the device via MQTT
class MusicPlayerWidget extends StatefulWidget {
  final String deviceId;

  const MusicPlayerWidget({
    Key? key,
    required this.deviceId,
  }) : super(key: key);

  @override
  State<MusicPlayerWidget> createState() => _MusicPlayerWidgetState();
}

class _MusicPlayerWidgetState extends State<MusicPlayerWidget> {
  AudioTrack? _selectedTrack;
  double _volume = 50.0;
  bool _isLooping = false;
  bool _isPlaying = false;

  final List<AudioTrack> _tracks = [
    AudioTrack(
      id: 'lullaby_1',
      name: "Brahms' Lullaby",
      duration: const Duration(minutes: 3),
      icon: Icons.music_note,
    ),
    AudioTrack(
      id: 'lullaby_2',
      name: 'Twinkle Twinkle',
      duration: const Duration(minutes: 2, seconds: 30),
      icon: Icons.music_note,
    ),
    AudioTrack(
      id: 'white_noise',
      name: 'White Noise',
      duration: null,
      icon: Icons.graphic_eq,
    ),
    AudioTrack(
      id: 'rain',
      name: 'Gentle Rain',
      duration: null,
      icon: Icons.water_drop,
    ),
    AudioTrack(
      id: 'heartbeat',
      name: 'Heartbeat',
      duration: null,
      icon: Icons.favorite,
    ),
    AudioTrack(
      id: 'ocean_waves',
      name: 'Ocean Waves',
      duration: null,
      icon: Icons.waves,
    ),
    AudioTrack(
      id: 'shushing',
      name: 'Shushing Sound',
      duration: null,
      icon: Icons.volume_up,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final mqttProvider = Provider.of<DeviceMqttProvider>(context);
    final deviceFound = mqttProvider.isDeviceOnline(widget.deviceId) ||
        mqttProvider.devices.any((d) => d.deviceId == widget.deviceId);

    return SizedBox(
      width: double.infinity,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  const Icon(Icons.music_note, size: 28),
                  const SizedBox(width: 12),
                  const Text(
                    'Soothing Sounds',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  if (_isPlaying)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.play_arrow, size: 16, color: Colors.green),
                          SizedBox(width: 4),
                          Text(
                            'Playing',
                            style: TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),

              if (!deviceFound) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.withOpacity(0.4)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.warning_amber, color: Colors.orange, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Device not connected. Open the Dashboard first to establish a connection.',
                          style: TextStyle(fontSize: 13, color: Colors.orange),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 20),

              // Track Selection
              const Text(
                'Select Track',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<AudioTrack>(
                value: _selectedTrack,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                hint: const Text('Choose a soothing sound...'),
                items: _tracks.map((track) {
                  return DropdownMenuItem(
                    value: track,
                    child: Row(
                      children: [
                        Icon(track.icon, size: 20),
                        const SizedBox(width: 12),
                        Expanded(child: Text(track.name)),
                        if (track.duration != null)
                          Text(
                            _formatDuration(track.duration!),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'Continuous',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.blue,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (track) {
                  setState(() {
                    _selectedTrack = track;
                  });
                },
              ),

              const SizedBox(height: 24),

              // Volume Control
              Row(
                children: [
                  const Icon(Icons.volume_down, size: 20),
                  Expanded(
                    child: Slider(
                      value: _volume,
                      min: 0,
                      max: 100,
                      divisions: 20,
                      label: '${_volume.round()}%',
                      onChanged: (value) {
                        setState(() {
                          _volume = value;
                        });
                      },
                      onChangeEnd: (value) {
                        if (_isPlaying) {
                          mqttProvider.sendCommand(
                            widget.deviceId,
                            'set_volume',
                            {'volume': value.round()},
                          );
                        }
                      },
                    ),
                  ),
                  const Icon(Icons.volume_up, size: 20),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 50,
                    child: Text(
                      '${_volume.round()}%',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Loop Toggle
              SwitchListTile(
                title: const Text('Loop continuously'),
                subtitle: const Text('Repeat sound until stopped'),
                value: _isLooping,
                onChanged: (value) {
                  setState(() {
                    _isLooping = value;
                  });
                },
                contentPadding: EdgeInsets.zero,
              ),

              const SizedBox(height: 24),

              // Playback Controls
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _selectedTrack == null || _isPlaying
                          ? null
                          : () async {
                              setState(() {
                                _isPlaying = true;
                              });

                              final success = await mqttProvider.sendCommand(
                                widget.deviceId,
                                'play_audio',
                                {'track': _selectedTrack!.id},
                              );

                              if (!success && mounted) {
                                setState(() {
                                  _isPlaying = false;
                                });
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                        'Device not reachable — open Dashboard first'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            },
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Play'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: !_isPlaying
                          ? null
                          : () async {
                              setState(() {
                                _isPlaying = false;
                              });
                              await mqttProvider.sendCommand(
                                  widget.deviceId, 'stop_audio');
                            },
                      icon: const Icon(Icons.stop),
                      label: const Text('Stop'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Safety Note
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.withOpacity(0.3)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, size: 20, color: Colors.blue[700]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Recommended volume: 40-60%. Speaker placed 7+ feet from crib. Plays on board speaker via MQTT.',
                        style: TextStyle(fontSize: 12, color: Colors.blue[700]),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}
