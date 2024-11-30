import 'package:flutter/material.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:just_audio/just_audio.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '○度寝目覚まし⏰',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  static const String wakeUpHourKey = 'wake_up_hour';
  static const String wakeUpMinuteKey = 'wake_up_minute';
  static const String finalAlarmHourKey = 'final_alarm_hour';
  static const String finalAlarmMinuteKey = 'final_alarm_minute';
  static const String intervalMinutesKey = 'interval_minutes';

  TimeOfDay? wakeUpTime;
  TimeOfDay? finalAlarmTime;
  List<TimeOfDay> alarmTimes = [];
  int intervalMinutes = 5;

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    tz.initializeTimeZones();
    _loadSavedSettings();
    _initializeNotifications();
    _initializeAudio();
  }

  Future<void> _initializeNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    final DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestSoundPermission: true,
      requestBadgePermission: true,
      requestAlertPermission: true,
    );
    final InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );
    await flutterLocalNotificationsPlugin.initialize(initializationSettings);
  }

  Future<void> _initializeAudio() async {
    await _audioPlayer.setAsset('assets/An_alarm_clock_that_would_not_startle_you.mp3');
  }

  Future<void> _scheduleAlarms() async {
    await flutterLocalNotificationsPlugin.cancelAll();
    
    final now = DateTime.now();
    for (TimeOfDay alarmTime in alarmTimes) {
      final dateTime = DateTime(
        now.year,
        now.month,
        now.day,
        alarmTime.hour,
        alarmTime.minute,
      );
      
      final int id = dateTime.millisecondsSinceEpoch ~/ 1000;
      
      await flutterLocalNotificationsPlugin.zonedSchedule(
        id,
        'アラーム',
        '起床時間です',
        tz.TZDateTime.from(dateTime, tz.local),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'alarm_channel',
            'Alarm Channel',
            channelDescription: 'Channel for alarm notifications',
            importance: Importance.max,
            priority: Priority.high,
            sound: RawResourceAndroidNotificationSound('an_alarm_clock_that_would_not_startle_you'),
          ),
          iOS: DarwinNotificationDetails(
            sound: 'An_alarm_clock_that_would_not_startle_you.aiff',
            presentSound: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.blue,
        title: Text(
          _getDateString(),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: Column(
            children: <Widget>[
              Container(
                width: 200,
                height: 75,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(16.0),
                ),
                child: StreamBuilder(
                  stream: Stream.periodic(const Duration(seconds: 1)),
                  builder: (context, snapshot) {
                    return Center(
                      child: Text(
                        _getTimeString(),
                        style: GoogleFonts.orbitron(
                          fontSize: 50,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Column(
                    children: [
                      ElevatedButton(
                        onPressed: () async {
                          final TimeOfDay? picked = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay.now(),
                          );
                          if (picked != null) {
                            setState(() {
                              wakeUpTime = picked;
                              generateAlarmTimes();
                            });
                            await _saveSettings();
                          }
                        },
                        child: const Text('起床開始時刻',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 8),
                      if (wakeUpTime != null)
                        Text(
                          wakeUpTime!.format(context),
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 32),
                        ),
                    ],
                  ),
                  const SizedBox(width: 24),
                  Column(
                    children: [
                      ElevatedButton(
                        onPressed: () async {
                          final TimeOfDay? picked = await showTimePicker(
                            context: context,
                            initialTime: wakeUpTime ?? TimeOfDay.now(),
                          );
                          if (picked != null) {
                            if (wakeUpTime != null &&
                                isValidFinalTime(picked)) {
                              setState(() {
                                finalAlarmTime = picked;
                                generateAlarmTimes();
                              });
                              await _saveSettings();
                            } else {
                              showInvalidTimeDialog();
                            }
                          }
                        },
                        child: const Text('最終アラーム時刻',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 8),
                      if (finalAlarmTime != null)
                        Text(
                          finalAlarmTime!.format(context),
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 32),
                        ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('アラーム間隔: '),
                  DropdownButton<int>(
                    value: intervalMinutes,
                    items: [1, 3, 5, 10, 15, 20, 30].map((int value) {
                      return DropdownMenuItem<int>(
                        value: value,
                        child: Text('$value分'),
                      );
                    }).toList(),
                    onChanged: (int? newValue) async {
                      if (newValue != null) {
                        setState(() {
                          intervalMinutes = newValue;
                          generateAlarmTimes();
                        });
                        await _saveSettings();
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool isValidFinalTime(TimeOfDay finalTime) {
    if (wakeUpTime == null) return false;

    final now = DateTime.now();
    final start = DateTime(
      now.year,
      now.month,
      now.day,
      wakeUpTime!.hour,
      wakeUpTime!.minute,
    );
    final end = DateTime(
      now.year,
      now.month,
      now.day,
      finalTime.hour,
      finalTime.minute,
    );

    return end.isAfter(start);
  }

  void showInvalidTimeDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('エラー'),
          content: const Text('最終アラーム時刻は起床開始時刻より後に設定してください。'),
          actions: <Widget>[
            TextButton(
              child: const Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void generateAlarmTimes() {
    if (wakeUpTime == null || finalAlarmTime == null) return;

    alarmTimes.clear();

    final now = DateTime.now();
    DateTime currentTime = DateTime(
      now.year,
      now.month,
      now.day,
      wakeUpTime!.hour,
      wakeUpTime!.minute,
    );

    final endTime = DateTime(
      now.year,
      now.month,
      now.day,
      finalAlarmTime!.hour,
      finalAlarmTime!.minute,
    );

    while (currentTime.isBefore(endTime) ||
        currentTime.isAtSameMomentAs(endTime)) {
      alarmTimes.add(TimeOfDay(
        hour: currentTime.hour,
        minute: currentTime.minute,
      ));
      currentTime = currentTime.add(Duration(minutes: intervalMinutes));
    }

    _scheduleAlarms();
  }

  String _getDateString() {
    final now = DateTime.now();
    final weekDay = ['日', '月', '火', '水', '木', '金', '土'][now.weekday % 7];
    return '${now.year}年${_formatNumber(now.month)}月${_formatNumber(now.day)}日(${weekDay})';
  }

  String _getTimeString() {
    final now = DateTime.now();
    return '${_formatNumber(now.hour)}:${_formatNumber(now.minute)}';
  }

  String _formatNumber(int number) {
    return number.toString().padLeft(2, '0');
  }

  // 設定を読み込む
  Future<void> _loadSavedSettings() async {
    final prefs = await SharedPreferences.getInstance();

    final wakeUpHour = prefs.getInt(wakeUpHourKey);
    final wakeUpMinute = prefs.getInt(wakeUpMinuteKey);
    if (wakeUpHour != null && wakeUpMinute != null) {
      setState(() {
        wakeUpTime = TimeOfDay(hour: wakeUpHour, minute: wakeUpMinute);
      });
    }

    final finalHour = prefs.getInt(finalAlarmHourKey);
    final finalMinute = prefs.getInt(finalAlarmMinuteKey);
    if (finalHour != null && finalMinute != null) {
      setState(() {
        finalAlarmTime = TimeOfDay(hour: finalHour, minute: finalMinute);
      });
    }

    setState(() {
      intervalMinutes = prefs.getInt(intervalMinutesKey) ?? 5;
    });

    if (wakeUpTime != null && finalAlarmTime != null) {
      generateAlarmTimes();
    }
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();

    if (wakeUpTime != null) {
      await prefs.setInt(wakeUpHourKey, wakeUpTime!.hour);
      await prefs.setInt(wakeUpMinuteKey, wakeUpTime!.minute);
    }

    if (finalAlarmTime != null) {
      await prefs.setInt(finalAlarmHourKey, finalAlarmTime!.hour);
      await prefs.setInt(finalAlarmMinuteKey, finalAlarmTime!.minute);
    }

    await prefs.setInt(intervalMinutesKey, intervalMinutes);
  }
}
