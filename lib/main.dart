import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:permission_handler/permission_handler.dart';
import 'package:file_picker/file_picker.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:async';
import 'dart:convert';

// ── NOTIFICATIONS ─────────────────────────────────────────
final FlutterLocalNotificationsPlugin notifs = FlutterLocalNotificationsPlugin();
const _alarmChannel = MethodChannel('com.example.clock_app/alarm');

Future<void> initNotifications() async {
  tz.initializeTimeZones();
  const android = AndroidInitializationSettings('@mipmap/ic_launcher');
  await notifs.initialize(
    settings: const InitializationSettings(android: android),
  );
}

Future<void> scheduleAlarm(AlarmModel alarm) async {
  if (!alarm.enabled) return;
  final now = DateTime.now();
  var alarmTime = DateTime(now.year, now.month, now.day, alarm.hour, alarm.minute);
  if (alarmTime.isBefore(now)) {
    alarmTime = alarmTime.add(const Duration(days: 1));
  }
  await _alarmChannel.invokeMethod('scheduleAlarm', {
    'id': alarm.id.hashCode,
    'triggerTime': alarmTime.millisecondsSinceEpoch,
    'label': alarm.label.isEmpty ? 'Alarm' : alarm.label,
    'soundPath': alarm.soundPath,
  });
}

Future<void> cancelAlarm(String id) async {
  await _alarmChannel.invokeMethod('cancelAlarm', {'id': id.hashCode});
}

// ── THEME ─────────────────────────────────────────────────
const kBg      = Color(0xFF0D0D0D);
const kSurface = Color(0xFF161616);
const kBorder  = Color(0xFF252525);
const kText    = Color(0xFFE8E2D9);
const kMuted   = Color(0xFF666666);
const kAccent  = Color(0xFFC8F060);
const kRed     = Color(0xFFF06060);

// ── MODELS ────────────────────────────────────────────────
class AlarmModel {
  String id;
  int hour;
  int minute;
  bool enabled;
  String label;
  List<bool> days;
  String? soundPath;
  String? soundName;

  AlarmModel({
    required this.id,
    required this.hour,
    required this.minute,
    this.enabled = true,
    this.label = '',
    List<bool>? days,
    this.soundPath,
    this.soundName,
  }) : days = days ?? List.filled(7, false);

  Map<String, dynamic> toJson() => {
    'id': id,
    'hour': hour,
    'minute': minute,
    'enabled': enabled,
    'label': label,
    'days': days,
    'soundPath': soundPath,
    'soundName': soundName,
  };

  factory AlarmModel.fromJson(Map<String, dynamic> j) => AlarmModel(
    id: j['id'],
    hour: j['hour'],
    minute: j['minute'],
    enabled: j['enabled'] ?? true,
    label: j['label'] ?? '',
    days: List<bool>.from(j['days'] ?? List.filled(7, false)),
    soundPath: j['soundPath'],
    soundName: j['soundName'],
  );

  String get timeString =>
    '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  String get daysString {
    const names = ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'];
    final active = <String>[];
    for (int i = 0; i < 7; i++) { if (days[i]) active.add(names[i]); }
    if (active.isEmpty) return 'Once';
    if (active.length == 7) return 'Every day';
    if (active.length == 5 && !days[5] && !days[6]) return 'Weekdays';
    return active.join(' ');
  }

  String get ringsInString {
    final now = DateTime.now();
    var alarmTime = DateTime(now.year, now.month, now.day, hour, minute);
    if (alarmTime.isBefore(now)) {
      alarmTime = alarmTime.add(const Duration(days: 1));
    }
    final diff = alarmTime.difference(now);
    final h = diff.inHours;
    final m = diff.inMinutes.remainder(60);
    if (h == 0) return 'Rings in ${m}m';
    if (m == 0) return 'Rings in ${h}h';
    return 'Rings in ${h}h ${m}m';
  }
}

// ── APP ───────────────────────────────────────────────────
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initNotifications();
  runApp(const ClockApp());
}

class ClockApp extends StatelessWidget {
  const ClockApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Clock',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: kBg,
        colorScheme: const ColorScheme.dark(primary: kAccent, surface: kSurface),
        fontFamily: 'monospace',
      ),
      home: const ClockHome(),
    );
  }
}

// ── HOME ──────────────────────────────────────────────────
class ClockHome extends StatefulWidget {
  const ClockHome({super.key});
  @override
  State<ClockHome> createState() => _ClockHomeState();
}

class _ClockHomeState extends State<ClockHome> {
  int _tab = 0;
  final _tabs = ['CLOCK', 'ALARM', 'STOPWATCH', 'TIMER'];

  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
  await Permission.notification.request();
  final exactAlarm = await Permission.scheduleExactAlarm.status;
  if (!exactAlarm.isGranted) {
    await Permission.scheduleExactAlarm.request();
  }
  if (!await Permission.scheduleExactAlarm.isGranted) {
    await openAppSettings();
  }
  
  // Request battery optimization exemption
  try {
    const platform = MethodChannel('com.example.clock_app/alarm');
    await platform.invokeMethod('requestBatteryOptimization');
  } catch (e) {
    // silently fail
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: kBorder)),
              ),
              child: Row(
                children: List.generate(_tabs.length, (i) => Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _tab = i),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        border: Border(bottom: BorderSide(
                          color: _tab == i ? kAccent : Colors.transparent,
                          width: 2,
                        )),
                      ),
                      child: Text(
                        _tabs[i],
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 10,
                          letterSpacing: 2,
                          color: _tab == i ? kAccent : kMuted,
                        ),
                      ),
                    ),
                  ),
                )),
              ),
            ),
            Expanded(
              child: IndexedStack(
                index: _tab,
                children: const [
                  ClockTab(),
                  AlarmTab(),
                  StopwatchTab(),
                  TimerTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── CLOCK TAB ─────────────────────────────────────────────
class ClockTab extends StatefulWidget {
  const ClockTab({super.key});
  @override
  State<ClockTab> createState() => _ClockTabState();
}

class _ClockTabState extends State<ClockTab> {
  late Timer _timer;
  late DateTime _now;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() { _timer.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final h = _now.hour.toString().padLeft(2, '0');
    final m = _now.minute.toString().padLeft(2, '0');
    final s = _now.second.toString().padLeft(2, '0');
    const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    const months = ['January', 'February', 'March', 'April', 'May', 'June',
                    'July', 'August', 'September', 'October', 'November', 'December'];
    final dayName = days[_now.weekday - 1];
    final monthName = months[_now.month - 1];

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('$h:$m', style: const TextStyle(
            fontSize: 96, fontWeight: FontWeight.w100, color: kText,
            letterSpacing: -2, fontFamily: 'monospace',
          )),
          Text(s, style: const TextStyle(
            fontSize: 32, color: kAccent, fontFamily: 'monospace')),
          const SizedBox(height: 24),
          Text(
            '$dayName, ${_now.day} $monthName ${_now.year}'.toUpperCase(),
            style: const TextStyle(fontSize: 11, color: kMuted, letterSpacing: 3),
          ),
        ],
      ),
    );
  }
}

// ── ALARM TAB ─────────────────────────────────────────────
class AlarmTab extends StatefulWidget {
  const AlarmTab({super.key});
  @override
  State<AlarmTab> createState() => _AlarmTabState();
}

class _AlarmTabState extends State<AlarmTab> {
  List<AlarmModel> alarms = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList('alarms') ?? [];
    setState(() {
      alarms = raw.map((s) => AlarmModel.fromJson(json.decode(s))).toList();
    });
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'alarms', alarms.map((a) => json.encode(a.toJson())).toList());
  }

  void _addAlarm() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AlarmEditPage()),
    );
    if (result != null) {
      setState(() => alarms.add(result));
      await _save();
      await scheduleAlarm(result);
    }
  }

  void _editAlarm(AlarmModel alarm) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AlarmEditPage(alarm: alarm)),
    );
    if (result != null) {
      setState(() {
        final idx = alarms.indexWhere((a) => a.id == alarm.id);
        if (idx >= 0) alarms[idx] = result;
      });
      await cancelAlarm(alarm.id);
      await _save();
      await scheduleAlarm(result);
    }
  }

  void _deleteAlarm(String id) async {
    await cancelAlarm(id);
    setState(() => alarms.removeWhere((a) => a.id == id));
    _save();
  }

  void _toggleAlarm(int idx, bool value) async {
    setState(() => alarms[idx].enabled = value);
    await _save();
    if (value) {
      await scheduleAlarm(alarms[idx]);
    } else {
      await cancelAlarm(alarms[idx].id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          child: Row(
            children: [
              const Text('ALARMS',
                style: TextStyle(fontSize: 11, color: kMuted, letterSpacing: 3)),
              const Spacer(),
              GestureDetector(
                onTap: _addAlarm,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    border: Border.all(color: kAccent.withValues(alpha: 0.4)),
                    borderRadius: BorderRadius.circular(4),
                    color: kAccent.withValues(alpha: 0.05),
                  ),
                  child: const Text('+ ALARM',
                    style: TextStyle(fontSize: 10, color: kAccent, letterSpacing: 2)),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: alarms.isEmpty
            ? const Center(child: Text('No alarms',
                style: TextStyle(color: kMuted, fontSize: 12, letterSpacing: 2)))
            : ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                itemCount: alarms.length,
                itemBuilder: (_, i) {
                  final a = alarms[i];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: kSurface,
                      border: Border.all(
                        color: a.enabled ? kBorder : kBorder.withValues(alpha: 0.3)),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () => _editAlarm(a),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(a.timeString, style: TextStyle(
                                fontSize: 36,
                                color: a.enabled ? kText : kMuted,
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.w200,
                              )),
                              Row(children: [
                                if (a.label.isNotEmpty) ...[
                                  Text(a.label,
                                    style: const TextStyle(fontSize: 11, color: kMuted)),
                                  const Text('  ·  ',
                                    style: TextStyle(color: kBorder)),
                                ],
                                Text(a.daysString,
                                  style: const TextStyle(fontSize: 11, color: kMuted)),
                              ]),
                              if (a.enabled)
                                Text(a.ringsInString,
                                  style: const TextStyle(
                                    fontSize: 10, color: kAccent, letterSpacing: 1)),
                            ],
                          ),
                        ),
                        const Spacer(),
                        Column(
                          children: [
                            Switch(
                              value: a.enabled,
                              onChanged: (v) => _toggleAlarm(i, v),
                              activeThumbColor: kAccent,
                              inactiveTrackColor: kBorder,
                            ),
                            GestureDetector(
                              onTap: () => _deleteAlarm(a.id),
                              child: const Icon(Icons.delete_outline,
                                color: kMuted, size: 18),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
        ),
      ],
    );
  }
}

// ── ALARM EDIT PAGE ───────────────────────────────────────
class AlarmEditPage extends StatefulWidget {
  final AlarmModel? alarm;
  const AlarmEditPage({super.key, this.alarm});
  @override
  State<AlarmEditPage> createState() => _AlarmEditPageState();
}

class _AlarmEditPageState extends State<AlarmEditPage> {
  late int hour;
  late int minute;
  late String label;
  late List<bool> days;
  String? soundPath;
  String? soundName;
  late TextEditingController labelCtrl;
  late FixedExtentScrollController _hourCtrl;
  late FixedExtentScrollController _minCtrl;
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    hour = widget.alarm?.hour ?? TimeOfDay.now().hour;
    minute = widget.alarm?.minute ?? TimeOfDay.now().minute;
    label = widget.alarm?.label ?? '';
    days = List.from(widget.alarm?.days ?? List.filled(7, false));
    soundPath = widget.alarm?.soundPath;
    soundName = widget.alarm?.soundName;
    labelCtrl = TextEditingController(text: label);
    _hourCtrl = FixedExtentScrollController(initialItem: hour);
    _minCtrl = FixedExtentScrollController(initialItem: minute);
  }

  @override
  void dispose() {
    _hourCtrl.dispose();
    _minCtrl.dispose();
    labelCtrl.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  String get _ringsIn {
    final now = DateTime.now();
    var alarmTime = DateTime(now.year, now.month, now.day, hour, minute);
    if (alarmTime.isBefore(now)) {
      alarmTime = alarmTime.add(const Duration(days: 1));
    }
    final diff = alarmTime.difference(now);
    final h = diff.inHours;
    final m = diff.inMinutes.remainder(60);
    if (h == 0) return 'Rings in ${m}m';
    if (m == 0) return 'Rings in ${h}h';
    return 'Rings in ${h}h ${m}m';
  }

  Future<void> _pickSound() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
      allowMultiple: false,
    );
    if (result != null && result.files.isNotEmpty) {
      setState(() {
        soundPath = result.files.first.path;
        soundName = result.files.first.name;
        _isPlaying = false;
      });
      await _audioPlayer.stop();
    }
  }

  Future<void> _togglePreview() async {
    if (_isPlaying) {
      await _audioPlayer.stop();
      setState(() => _isPlaying = false);
    } else {
      if (soundPath != null) {
        await _audioPlayer.play(DeviceFileSource(soundPath!));
      } else {
        // Play default ringtone via platform
        await _audioPlayer.play(AssetSource('alarm_default.mp3'));
      }
      setState(() => _isPlaying = true);
      _audioPlayer.onPlayerComplete.listen((_) {
        if (mounted) setState(() => _isPlaying = false);
      });
    }
  }

  AlarmModel get result => AlarmModel(
    id: widget.alarm?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
    hour: hour,
    minute: minute,
    label: labelCtrl.text,
    days: days,
    soundPath: soundPath,
    soundName: soundName,
  );

  Widget _scrollPicker(
    String label,
    int max,
    FixedExtentScrollController ctrl,
    ValueChanged<int> onChanged,
  ) {
    return Column(
      children: [
        Text(label, style: const TextStyle(
          fontSize: 9, color: kMuted, letterSpacing: 3)),
        const SizedBox(height: 8),
        SizedBox(
          width: 80,
          height: 160,
          child: ListWheelScrollView.useDelegate(
            controller: ctrl,
            itemExtent: 52,
            perspective: 0.002,
            diameterRatio: 1.4,
            physics: const FixedExtentScrollPhysics(),
            onSelectedItemChanged: (i) {
              HapticFeedback.lightImpact();
              onChanged(i);
            },
            childDelegate: ListWheelChildBuilderDelegate(
              childCount: max + 1,
              builder: (_, i) {
                final selected = i == (label == 'HOUR' ? hour : minute);
                return Center(
                  child: Text(
                    i.toString().padLeft(2, '0'),
                    style: TextStyle(
                      fontSize: selected ? 36 : 24,
                      color: selected ? kAccent : kMuted,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w200,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      _audioPlayer.stop();
                      Navigator.pop(context);
                    },
                    child: const Icon(Icons.arrow_back, color: kMuted, size: 20),
                  ),
                  const SizedBox(width: 16),
                  const Text('ALARM', style: TextStyle(
                    fontSize: 11, letterSpacing: 4, color: kAccent)),
                  const Spacer(),
                  GestureDetector(
                    onTap: () {
                      _audioPlayer.stop();
                      Navigator.pop(context, result);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: kAccent,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text('SAVE', style: TextStyle(
                        fontSize: 10, color: kBg,
                        letterSpacing: 2, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Divider(color: kBorder, height: 1),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Time picker
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _scrollPicker('HOUR', 23, _hourCtrl,
                          (v) => setState(() => hour = v)),
                        const Padding(
                          padding: EdgeInsets.only(top: 24),
                          child: Text(':', style: TextStyle(
                            fontSize: 36, color: kMuted, fontFamily: 'monospace')),
                        ),
                        _scrollPicker('MIN', 59, _minCtrl,
                          (v) => setState(() => minute = v)),
                      ],
                    ),
                    Center(
                      child: Text(_ringsIn, style: const TextStyle(
                        fontSize: 12, color: kAccent, letterSpacing: 2)),
                    ),
                    const SizedBox(height: 24),
                    const Divider(color: kBorder),
                    const SizedBox(height: 16),

                    // Label
                    const Text('LABEL', style: TextStyle(
                      fontSize: 9, color: kMuted, letterSpacing: 3)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: labelCtrl,
                      style: const TextStyle(color: kText, fontSize: 14),
                      decoration: const InputDecoration(
                        hintText: 'Alarm label...',
                        hintStyle: TextStyle(color: kMuted),
                        border: UnderlineInputBorder(
                          borderSide: BorderSide(color: kBorder)),
                        focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: kAccent)),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Repeat days
                    const Text('REPEAT', style: TextStyle(
                      fontSize: 9, color: kMuted, letterSpacing: 3)),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(7, (i) {
                        const names = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
                        return GestureDetector(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            setState(() => days[i] = !days[i]);
                          },
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: days[i] ? kAccent : kBorder,
                            ),
                            child: Center(child: Text(names[i],
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: days[i] ? kBg : kMuted,
                              ))),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 24),

                    // Sound picker
                    const Text('SOUND', style: TextStyle(
                      fontSize: 9, color: kMuted, letterSpacing: 3)),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: kSurface,
                        border: Border.all(color: kBorder),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Column(
                        children: [
                          // Pick sound row
                          GestureDetector(
                            onTap: _pickSound,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
                              child: Row(
                                children: [
                                  const Icon(Icons.music_note,
                                    color: kMuted, size: 18),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      soundName ?? 'Default alarm sound',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: soundName != null ? kText : kMuted,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const Icon(Icons.chevron_right,
                                    color: kMuted, size: 18),
                                ],
                              ),
                            ),
                          ),
                          // Preview row
                          const Divider(color: kBorder, height: 1),
                          GestureDetector(
                            onTap: _togglePreview,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                              child: Row(
                                children: [
                                  Icon(
                                    _isPlaying ? Icons.stop : Icons.play_arrow,
                                    color: _isPlaying ? kRed : kAccent,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    _isPlaying ? 'Stop preview' : 'Preview sound',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: _isPlaying ? kRed : kAccent,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (soundName != null) ...[
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: () {
                          _audioPlayer.stop();
                          setState(() {
                            soundPath = null;
                            soundName = null;
                            _isPlaying = false;
                          });
                        },
                        child: const Text('Use default sound',
                          style: TextStyle(
                            fontSize: 11, color: kMuted,
                            decoration: TextDecoration.underline)),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── STOPWATCH TAB ─────────────────────────────────────────
class StopwatchTab extends StatefulWidget {
  const StopwatchTab({super.key});
  @override
  State<StopwatchTab> createState() => _StopwatchTabState();
}

class _StopwatchTabState extends State<StopwatchTab> {
  final Stopwatch _sw = Stopwatch();
  late Timer _timer;
  final List<Duration> _laps = [];
  Duration _elapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 30), (_) {
      if (_sw.isRunning) setState(() => _elapsed = _sw.elapsed);
    });
  }

  @override
  void dispose() { _timer.cancel(); _sw.stop(); super.dispose(); }

  String _fmt(Duration d) {
    final min = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final sec = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    final ms  = (d.inMilliseconds.remainder(1000) ~/ 10).toString().padLeft(2, '0');
    return '$min:$sec.$ms';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 48),
        Text(_fmt(_elapsed), style: const TextStyle(
          fontSize: 64, color: kText,
          fontFamily: 'monospace', fontWeight: FontWeight.w200,
        )),
        const SizedBox(height: 48),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            GestureDetector(
              onTap: () {
                if (_sw.isRunning) {
                  HapticFeedback.lightImpact();
                  setState(() => _laps.insert(0, _sw.elapsed));
                } else {
                  setState(() {
                    _sw.reset();
                    _elapsed = Duration.zero;
                    _laps.clear();
                  });
                }
              },
              child: Container(
                width: 72, height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: kBorder, width: 2),
                ),
                child: Center(child: Text(
                  _sw.isRunning ? 'LAP' : 'RESET',
                  style: const TextStyle(
                    fontSize: 11, color: kMuted, letterSpacing: 1),
                )),
              ),
            ),
            const SizedBox(width: 32),
            GestureDetector(
              onTap: () {
                HapticFeedback.mediumImpact();
                setState(() => _sw.isRunning ? _sw.stop() : _sw.start());
              },
              child: Container(
                width: 88, height: 88,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _sw.isRunning
                    ? kRed.withValues(alpha: 0.15)
                    : kAccent.withValues(alpha: 0.15),
                  border: Border.all(
                    color: _sw.isRunning ? kRed : kAccent, width: 2),
                ),
                child: Center(child: Text(
                  _sw.isRunning ? 'STOP' : 'START',
                  style: TextStyle(
                    fontSize: 12, letterSpacing: 1,
                    color: _sw.isRunning ? kRed : kAccent),
                )),
              ),
            ),
          ],
        ),
        const SizedBox(height: 32),
        Expanded(
          child: _laps.isEmpty
            ? const Center(child: Text('No laps',
                style: TextStyle(color: kMuted, fontSize: 11, letterSpacing: 2)))
            : ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                itemCount: _laps.length,
                itemBuilder: (_, i) {
                  final lapTime = i == _laps.length - 1
                    ? _laps[i]
                    : _laps[i] - _laps[i + 1];
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 12, horizontal: 16),
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(
                        color: kBorder.withValues(alpha: 0.5)))),
                    child: Row(
                      children: [
                        Text('LAP ${_laps.length - i}',
                          style: const TextStyle(
                            fontSize: 11, color: kMuted, letterSpacing: 1)),
                        const Spacer(),
                        Text(_fmt(lapTime),
                          style: const TextStyle(
                            fontSize: 16, color: kText, fontFamily: 'monospace')),
                        const SizedBox(width: 16),
                        Text(_fmt(_laps[i]),
                          style: const TextStyle(
                            fontSize: 12, color: kMuted, fontFamily: 'monospace')),
                      ],
                    ),
                  );
                },
              ),
        ),
      ],
    );
  }
}

// ── TIMER TAB ─────────────────────────────────────────────
class TimerTab extends StatefulWidget {
  const TimerTab({super.key});
  @override
  State<TimerTab> createState() => _TimerTabState();
}

class _TimerTabState extends State<TimerTab> {
  int _totalSeconds = 0;
  int _remaining = 0;
  bool _running = false;
  bool _finished = false;
  Timer? _timer;
  int _pickH = 0;
  int _pickM = 0;
  int _pickS = 0;

  late FixedExtentScrollController _hCtrl;
  late FixedExtentScrollController _mCtrl;
  late FixedExtentScrollController _sCtrl;

  @override
  void initState() {
    super.initState();
    _hCtrl = FixedExtentScrollController();
    _mCtrl = FixedExtentScrollController();
    _sCtrl = FixedExtentScrollController();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _hCtrl.dispose();
    _mCtrl.dispose();
    _sCtrl.dispose();
    super.dispose();
  }

  void _start() {
    _totalSeconds = _pickH * 3600 + _pickM * 60 + _pickS;
    if (_totalSeconds == 0) return;
    HapticFeedback.mediumImpact();
    setState(() { _remaining = _totalSeconds; _running = true; _finished = false; });
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        if (_remaining > 0) {
          _remaining--;
        } else {
          _running = false;
          _finished = true;
          _timer?.cancel();
          _showTimerNotification();
          HapticFeedback.heavyImpact();
        }
      });
    });
  }

  Future<void> _showTimerNotification() async {
    await notifs.show(
      id: 99999,
      title: 'Timer',
      body: 'Your timer has finished!',
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'timer_channel', 'Timer',
          channelDescription: 'Timer notifications',
          importance: Importance.max,
          priority: Priority.max,
          fullScreenIntent: true,
        ),
      ),
    );
  }

  void _pause() {
    HapticFeedback.lightImpact();
    _timer?.cancel();
    setState(() => _running = false);
  }

  void _resume() {
    HapticFeedback.lightImpact();
    setState(() { _running = true; _finished = false; });
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        if (_remaining > 0) {
          _remaining--;
        } else {
          _running = false;
          _finished = true;
          _timer?.cancel();
          _showTimerNotification();
        }
      });
    });
  }

  void _reset() {
    _timer?.cancel();
    setState(() {
      _remaining = 0; _running = false; _finished = false; _totalSeconds = 0;
    });
  }

  String _fmt(int secs) {
    final h = (secs ~/ 3600).toString().padLeft(2, '0');
    final m = ((secs % 3600) ~/ 60).toString().padLeft(2, '0');
    final s = (secs % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  double get _progress => _totalSeconds > 0 ? _remaining / _totalSeconds : 1.0;

  Widget _picker(String label, int max, FixedExtentScrollController ctrl,
    int value, ValueChanged<int> onChanged) {
    return Column(
      children: [
        Text(label, style: const TextStyle(
          fontSize: 9, color: kMuted, letterSpacing: 2)),
        SizedBox(
          width: 80, height: 160,
          child: ListWheelScrollView.useDelegate(
            controller: ctrl,
            itemExtent: 52,
            perspective: 0.002,
            diameterRatio: 1.4,
            physics: const FixedExtentScrollPhysics(),
            onSelectedItemChanged: (i) {
              HapticFeedback.lightImpact();
              onChanged(i);
            },
            childDelegate: ListWheelChildBuilderDelegate(
              childCount: max + 1,
              builder: (_, i) {
                final selected = i == value;
                return Center(
                  child: Text(
                    i.toString().padLeft(2, '0'),
                    style: TextStyle(
                      fontSize: selected ? 36 : 24,
                      color: selected ? kAccent : kMuted,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w200,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isSetup = !_running && _remaining == 0 && !_finished;

    return Column(
      children: [
        const SizedBox(height: 32),
        if (isSetup) ...[
          const Text('SET TIMER',
            style: TextStyle(fontSize: 10, color: kMuted, letterSpacing: 3)),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _picker('H', 23, _hCtrl, _pickH, (v) => setState(() => _pickH = v)),
              const Text(':', style: TextStyle(fontSize: 36, color: kMuted)),
              _picker('M', 59, _mCtrl, _pickM, (v) => setState(() => _pickM = v)),
              const Text(':', style: TextStyle(fontSize: 36, color: kMuted)),
              _picker('S', 59, _sCtrl, _pickS, (v) => setState(() => _pickS = v)),
            ],
          ),
          const SizedBox(height: 32),
          GestureDetector(
            onTap: _start,
            child: Container(
              width: 88, height: 88,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: kAccent.withValues(alpha: 0.15),
                border: Border.all(color: kAccent, width: 2),
              ),
              child: const Center(child: Text('START',
                style: TextStyle(
                  fontSize: 12, color: kAccent, letterSpacing: 1))),
            ),
          ),
        ] else ...[
          SizedBox(
            width: 220, height: 220,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 220, height: 220,
                  child: CircularProgressIndicator(
                    value: _progress,
                    strokeWidth: 4,
                    backgroundColor: kBorder,
                    valueColor: AlwaysStoppedAnimation(
                      _finished ? kRed : kAccent),
                  ),
                ),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(_fmt(_remaining), style: TextStyle(
                      fontSize: 48,
                      color: _finished ? kRed : kText,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w200,
                    )),
                    if (_finished)
                      const Text("TIME'S UP", style: TextStyle(
                        fontSize: 12, color: kRed, letterSpacing: 3)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 48),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: _reset,
                child: Container(
                  width: 72, height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: kBorder, width: 2),
                  ),
                  child: const Center(child: Text('RESET',
                    style: TextStyle(
                      fontSize: 11, color: kMuted, letterSpacing: 1))),
                ),
              ),
              const SizedBox(width: 32),
              GestureDetector(
                onTap: _running ? _pause : _resume,
                child: Container(
                  width: 88, height: 88,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _running
                      ? kRed.withValues(alpha: 0.15)
                      : kAccent.withValues(alpha: 0.15),
                    border: Border.all(
                      color: _running ? kRed : kAccent, width: 2),
                  ),
                  child: Center(child: Text(
                    _running ? 'PAUSE' : 'RESUME',
                    style: TextStyle(
                      fontSize: 11, letterSpacing: 1,
                      color: _running ? kRed : kAccent),
                  )),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}