import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '○度寝目覚まし',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: '○度寝目覚まし⏰'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  TimeOfDay? wakeUpTime;
  TimeOfDay? finalAlarmTime;
  List<TimeOfDay> alarmTimes = [];
  int intervalMinutes = 5;
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = 
    FlutterLocalNotificationsPlugin();

  @override
  void initState() {
    super.initState();
    _initializeNotifications();
    tz.initializeTimeZones();
  }

  // 通知の初期化
  Future<void> _initializeNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iOSSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    
    const initializationSettings = InitializationSettings(
      android: androidSettings,
      iOS: iOSSettings,
    );

    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // 通知がタップされた時の処理
      },
    );
  }

  // アラームを設定する関数
  Future<void> _scheduleAlarms() async {
    // 既存のアラームをすべてキャンセル
    await flutterLocalNotificationsPlugin.cancelAll();

    // 各アラーム時刻に対して通知を設定
    for (int i = 0; i < alarmTimes.length; i++) {
      final time = alarmTimes[i];
      final now = DateTime.now();
      var scheduledDate = DateTime(
        now.year,
        now.month,
        now.day,
        time.hour,
        time.minute,
      );

      // 設定時刻が過去の場合は翌日に設定
      if (scheduledDate.isBefore(now)) {
        scheduledDate = scheduledDate.add(const Duration(days: 1));
      }

      await _scheduleAlarm(i, scheduledDate);
    }
  }

  // 個別のアラームを設定
  Future<void> _scheduleAlarm(int id, DateTime scheduledDate) async {
    final androidDetails = AndroidNotificationDetails(
      'alarm_channel',
      'アラーム通知',
      channelDescription: 'アラーム通知用のチャンネル',
      importance: Importance.max,
      priority: Priority.high,
      sound: const RawResourceAndroidNotificationSound('alarm_sound'),
      fullScreenIntent: true,
    );

    final iOSDetails = const DarwinNotificationDetails(
      sound: 'alarm_sound.aiff',
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iOSDetails,
    );

    await flutterLocalNotificationsPlugin.zonedSchedule(
      id,
      '目覚まし時計',
      'アラーム時刻です',
      tz.TZDateTime.from(scheduledDate, tz.local),
      notificationDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.blue,
        title: Text(widget.title,
            style: const TextStyle(
                fontWeight: FontWeight.bold, color: Colors.white)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: Column(
            children: <Widget>[
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
                  }
                },
                child: const Text('起床開始時刻を設定',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 8),
              if (wakeUpTime != null)
                Text(
                  '起床開始時刻: ${wakeUpTime!.format(context)}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () async {
                  final TimeOfDay? picked = await showTimePicker(
                    context: context,
                    initialTime: wakeUpTime ?? TimeOfDay.now(),
                  );
                  if (picked != null) {
                    if (wakeUpTime != null && isValidFinalTime(picked)) {
                      setState(() {
                        finalAlarmTime = picked;
                        generateAlarmTimes();
                      });
                    } else {
                      showInvalidTimeDialog();
                    }
                  }
                },
                child: const Text('最終アラーム時刻を設定',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 8),
              if (finalAlarmTime != null)
                Text(
                  '最終アラーム時刻: ${finalAlarmTime!.format(context)}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                ),
              const SizedBox(height: 20),
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
                    onChanged: (int? newValue) {
                      if (newValue != null) {
                        setState(() {
                          intervalMinutes = newValue;
                          generateAlarmTimes();
                        });
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

    // アラーム時刻リスト生成後に通知をスケジュール
    _scheduleAlarms();
  }
}
