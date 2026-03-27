import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hijri/hijri_calendar.dart';
import 'app_colors.dart';
import 'models/prayer_times_model.dart';
import 'services/prayer_api_service.dart';
import 'services/location_service.dart';
import 'services/alarm_service.dart';
import 'services/prefs_service.dart';
import 'services/firebase_service.dart';
import 'widgets/next_prayer_card.dart';
import 'widgets/prayer_row_widget.dart';
import 'widgets/control_button.dart';
import 'widgets/fiqa_dropdown.dart';
import 'widgets/device_battery_setup_guide.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  bool _azanOn = true;
  bool _ramzanOn = false;
  bool _isRamzan = false;
  FiqaType _fiqa = FiqaType.hanafi;

  final List<PrayerTime> _prayers = defaultPrayers();
  LocationResult? _location;
  bool _loadingLocation = true;
  bool _loadingPrayers = true;
  bool _updatingFiqa = false;
  String? _error;

  late Timer _clockTimer;
  DateTime _now = DateTime.now();
  int? _nextIdx;

  late AnimationController _fiqaFlashCtrl;

  @override
  void initState() {
    super.initState();
    _fiqaFlashCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _init();
    _startClock();
  }

  @override
  void dispose() {
    _clockTimer.cancel();
    _fiqaFlashCtrl.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    _azanOn = PrefsService.azanOn;
    _ramzanOn = PrefsService.ramzanOn;
    _fiqa = PrefsService.fiqa;

    for (final p in _prayers) {
      p.alarmOn = PrefsService.getPrayerToggle(p.key);
    }

    _detectRamzan();

    final loc = await LocationService.getLocation();
    if (mounted) {
      setState(() {
        _location = loc;
        _loadingLocation = false;
      });
    }

    await _fetchPrayers();

    if (_azanOn && mounted) {
      await AlarmService.scheduleAll(_prayers, ramzanOn: _ramzanOn);
    }

    _sendNextPrayerToService();
  }

  void _detectRamzan() {
    final hijri = HijriCalendar.now();
    setState(() => _isRamzan = hijri.hMonth == 9);
  }

  void _startClock() {
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _now = DateTime.now());
      _updateNextPrayer();
    });
  }

  void _updateNextPrayer() {
    final nowMins = _now.hour * 60 + _now.minute;
    int? nextIdx;
    int minDiff = 99999;

    for (int i = 0; i < _prayers.length; i++) {
      final t = _prayers[i].totalMinutes;
      int diff = t - nowMins;
      if (diff < 0) diff += 1440;
      if (diff < minDiff) {
        minDiff = diff;
        nextIdx = i;
      }
    }
    if (nextIdx != _nextIdx) {
      setState(() => _nextIdx = nextIdx);
    }
  }

  void _sendNextPrayerToService() {
    if (_nextIdx == null) return;
    final next = _prayers[_nextIdx!];
    if (next.time == null) return;

    final now = DateTime.now();
    var dt = DateTime(
        now.year, now.month, now.day, next.time!.hour, next.time!.minute);
    if (dt.isBefore(now)) dt = dt.add(const Duration(days: 1));

    try {
      const platform = MethodChannel('azan_service_channel');
      platform.invokeMethod('updateNextPrayer', {
        'next_prayer_name': next.name,
        'next_prayer_time_ms': dt.millisecondsSinceEpoch,
      });
    } catch (_) {}
  }

  Future<void> _fetchPrayers({bool isUpdate = false}) async {
    if (_location == null) return;
    setState(() {
      if (isUpdate) {
        _updatingFiqa = true;
      } else {
        _loadingPrayers = true;
      }
      _error = null;
    });

    try {
      final timings = await PrayerApiService.fetchTimes(
        lat: _location!.lat,
        lon: _location!.lon,
        fiqa: _fiqa,
      );
      PrayerApiService.applyTimings(_prayers, timings);
      _updateNextPrayer();

      if (_azanOn) {
        await AlarmService.scheduleAll(_prayers, ramzanOn: _ramzanOn);
      }

      // Register device with server — sends location + FCM token
      // Safe to call every time — server uses merge=True (no duplicates)
      FirebaseService.registerWithServer(
        lat: _location!.lat,
        lon: _location!.lon,
        city: _location!.city,
        timezone: 'Asia/Karachi',
        fiqa: _fiqa == FiqaType.jafari ? 'jafari' : 'hanafi',
      );

      if (isUpdate) _fiqaFlashCtrl.forward(from: 0);
    } catch (_) {
      setState(() => _error = 'Could not load prayer times. Check internet.');
    } finally {
      setState(() {
        _loadingPrayers = false;
        _updatingFiqa = false;
      });
    }
  }

  Future<void> _toggleAzan() async {
    setState(() => _azanOn = !_azanOn);
    await PrefsService.setAzanOn(_azanOn);

    try {
      const platform = MethodChannel('azan_service_channel');
      await platform.invokeMethod('setAzanOn', {'azan_on': _azanOn});
    } catch (_) {}

    if (_azanOn && _location != null) {
      await AlarmService.scheduleAll(_prayers, ramzanOn: _ramzanOn);
    } else {
      await AlarmService.cancelAll();
      if (_ramzanOn) {
        setState(() => _ramzanOn = false);
        await PrefsService.setRamzanOn(false);
      }
    }
  }

  Future<void> _toggleRamzan() async {
    if (!_azanOn) return;
    setState(() => _ramzanOn = !_ramzanOn);
    await PrefsService.setRamzanOn(_ramzanOn);

    if (_ramzanOn) {
      await AlarmService.scheduleRamzanAlarms(_prayers);
    } else {
      await AlarmService.cancelRamzanAlarms();
    }
  }

  Future<void> _switchFiqa(FiqaType f) async {
    if (f == _fiqa) return;
    setState(() => _fiqa = f);
    await PrefsService.setFiqa(f);
    await _fetchPrayers(isUpdate: true);
  }

  Future<void> _togglePrayerAlarm(PrayerTime prayer) async {
    setState(() => prayer.alarmOn = !prayer.alarmOn);
    await PrefsService.setPrayerToggle(prayer.key, prayer.alarmOn);
    if (_azanOn) await AlarmService.updateOne(prayer);
  }

  PrayerTime get _fajr =>
      _prayers.firstWhere((p) => p.key == 'Fajr', orElse: () => _prayers[0]);
  PrayerTime get _maghrib =>
      _prayers.firstWhere((p) => p.key == 'Maghrib', orElse: () => _prayers[4]);

  String get _sehriTime => _fajr.displayTime;
  String get _iftarTime => _maghrib.displayTime;

  String get _sehriWarningCountdown {
    if (_fajr.time == null) return '--';
    final nowMins = _now.hour * 60 + _now.minute;
    int warnMins = _fajr.totalMinutes - 60;
    if (warnMins < 0) warnMins += 1440;
    int diff = warnMins - nowMins;
    if (diff < 0) diff += 1440;
    final h = diff ~/ 60, m = diff % 60;
    return h > 0 ? '${h}h ${m.toString().padLeft(2, '0')}m' : '${m}m';
  }

  String get _iftarCountdown {
    if (_maghrib.time == null) return '--';
    final nowMins = _now.hour * 60 + _now.minute;
    int diff = _maghrib.totalMinutes - nowMins;
    if (diff < 0) diff += 1440;
    final h = diff ~/ 60, m = diff % 60;
    return h > 0 ? '${h}h ${m.toString().padLeft(2, '0')}m' : '${m}m';
  }

  String get _clockString {
    final h = _now.hour;
    final m = _now.minute;
    final ampm = h >= 12 ? 'PM' : 'AM';
    final h12 = h % 12 == 0 ? 12 : h % 12;
    return '${h12.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')} $ampm';
  }

  String get _dateString =>
      '${_weekday(_now.weekday)}, ${_now.day} ${_monthName(_now.month)}';

  String get _countdownString {
    if (_nextIdx == null || _prayers[_nextIdx!].time == null) return '--';
    final nowMins = _now.hour * 60 + _now.minute;
    int diff = _prayers[_nextIdx!].totalMinutes - nowMins;
    if (diff < 0) diff += 1440;
    final h = diff ~/ 60, m = diff % 60;
    return h > 0 ? '${h}h ${m.toString().padLeft(2, '0')}m' : '${m}m';
  }

  static const _weekdays = [
    '',
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun'
  ];
  static const _months = [
    '',
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec'
  ];
  String _weekday(int d) => _weekdays[d];
  String _monthName(int m) => _months[m];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -1),
            radius: 1.5,
            colors: [Color(0x17C9A84C), AppColors.bg],
          ),
        ),
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    const SizedBox(height: 16),
                    _buildHeader(),
                    const SizedBox(height: 12),
                    _buildBismillah(),
                    const SizedBox(height: 14),
                    if (_ramzanOn && !_loadingPrayers) ...[
                      _buildRamzanCard(),
                      const SizedBox(height: 10),
                    ],
                    _buildNextPrayerCard(),
                    const SizedBox(height: 16),
                    _buildSectionLabel('ALARM CONTROLS'),
                    const SizedBox(height: 8),
                    _buildControls(),
                    const SizedBox(height: 16),
                    _buildDivider(),
                    const SizedBox(height: 14),
                    _buildSectionLabel('PRAYER TIMES'),
                    const SizedBox(height: 8),
                    _buildPrayerList(),
                    const SizedBox(height: 24),
                    _buildTestAlarmSection(),
                    const SizedBox(height: 24),
                    const Center(
                      child: Text(
                        'Powered by TEAMHASAN',
                        style: TextStyle(
                          fontSize: 10,
                          color: AppColors.muted,
                          letterSpacing: 1.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRamzanCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A1500), Color(0xFF1C2333)],
        ),
        border: Border.all(color: AppColors.gold, width: 1),
        boxShadow: [
          BoxShadow(
            color: AppColors.gold.withValues(alpha: 0.15),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('☪️', style: TextStyle(fontSize: 14)),
              SizedBox(width: 6),
              Text('RAMZAN TIMINGS',
                  style: TextStyle(
                      fontSize: 10,
                      letterSpacing: 2.5,
                      color: AppColors.gold,
                      fontWeight: FontWeight.w700)),
              SizedBox(width: 6),
              Text('☪️', style: TextStyle(fontSize: 14)),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    const Text('🌙 SEHRI ENDS',
                        style: TextStyle(
                            fontSize: 9,
                            letterSpacing: 1.5,
                            color: AppColors.muted,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(_sehriTime,
                        style: const TextStyle(
                            fontSize: 22,
                            color: AppColors.gold2,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text('alarm in $_sehriWarningCountdown',
                        style: const TextStyle(
                            fontSize: 10, color: AppColors.muted)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.gold.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text('⏰ 1hr warning',
                          style: TextStyle(fontSize: 9, color: AppColors.gold)),
                    ),
                  ],
                ),
              ),
              Container(
                  width: 1,
                  height: 80,
                  color: AppColors.border,
                  margin: const EdgeInsets.symmetric(horizontal: 12)),
              Expanded(
                child: Column(
                  children: [
                    const Text('🌅 IFTAR',
                        style: TextStyle(
                            fontSize: 9,
                            letterSpacing: 1.5,
                            color: AppColors.muted,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(_iftarTime,
                        style: const TextStyle(
                            fontSize: 22,
                            color: AppColors.gold2,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text('in $_iftarCountdown',
                        style: const TextStyle(
                            fontSize: 10, color: AppColors.muted)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.teal.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text('🔔 Azan alarm',
                          style: TextStyle(fontSize: 9, color: AppColors.teal)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _refreshLocation() async {
    setState(() => _loadingLocation = true);
    final loc = await LocationService.forceRefresh();
    if (mounted) {
      setState(() {
        _location = loc;
        _loadingLocation = false;
      });
      await _fetchPrayers();
    }
  }

  Widget _buildHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('📍 LOCATION',
                    style: TextStyle(
                        fontSize: 10,
                        letterSpacing: 2,
                        color: AppColors.muted,
                        fontWeight: FontWeight.w700)),
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: _loadingLocation ? null : _refreshLocation,
                  child: _loadingLocation
                      ? const SizedBox(
                          width: 10,
                          height: 10,
                          child: CircularProgressIndicator(
                              strokeWidth: 1.5, color: AppColors.muted))
                      : const Icon(Icons.refresh_rounded,
                          size: 14, color: AppColors.muted),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                _GpsDot(active: !_loadingLocation),
                const SizedBox(width: 7),
                Text(
                  _loadingLocation
                      ? 'Locating…'
                      : (_location?.city ?? 'Unknown'),
                  style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppColors.gold,
                      height: 1.1),
                ),
              ],
            ),
            Text(
              _loadingLocation ? '' : (_location?.country ?? ''),
              style: const TextStyle(fontSize: 12, color: AppColors.muted),
            ),
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'battery') {
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => DeviceBatterySetupGuide(
                      onComplete: () => Navigator.of(context).pop(),
                    ),
                  ));
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem<String>(
                  value: 'battery',
                  child: Row(
                    children: [
                      Text('🔋 ', style: TextStyle(fontSize: 16)),
                      SizedBox(width: 8),
                      Text('Battery Optimization'),
                    ],
                  ),
                ),
              ],
              icon:
                  const Icon(Icons.more_vert, color: AppColors.muted, size: 20),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            const SizedBox(height: 8),
            Text(_clockString,
                style: const TextStyle(
                    fontSize: 28,
                    color: AppColors.textMain,
                    fontWeight: FontWeight.w300,
                    height: 1)),
            Text(_dateString,
                style: const TextStyle(fontSize: 11, color: AppColors.muted)),
          ],
        ),
      ],
    );
  }

  Widget _buildBismillah() {
    return Center(
      child: Text(
        'بِسْمِ اللَّهِ الرَّحْمَنِ الرَّحِيم',
        style: TextStyle(
          fontSize: 22,
          color: AppColors.gold,
          shadows: [
            Shadow(color: AppColors.gold.withValues(alpha: 0.4), blurRadius: 20)
          ],
        ),
      ),
    );
  }

  Widget _buildNextPrayerCard() {
    final next = _nextIdx != null ? _prayers[_nextIdx!] : null;
    return NextPrayerCard(
      prayerName: next?.name ?? '—',
      prayerTime: next?.displayTime ?? '--:--',
      countdown: _countdownString,
    );
  }

  Widget _buildControls() {
    return Column(
      children: [
        ControlButton(
          label: _azanOn ? 'Azan Alarm — ON' : 'Azan Alarm — OFF',
          icon: '🕌',
          isOn: _azanOn,
          onTap: _toggleAzan,
          activeColor: AppColors.green,
          activeBg: const Color(0xFF0D1A0D),
          activeBorder: AppColors.green,
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeInOut,
          child: _azanOn
              ? Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: FiqaDropdown(
                      selected: _fiqa,
                      updating: _updatingFiqa,
                      onSelected: _switchFiqa),
                )
              : const SizedBox.shrink(),
        ),
        const SizedBox(height: 8),
        ControlButton(
          label: _ramzanOn ? 'Ramzan Mode — ON' : 'Ramzan Mode',
          icon: '☪️',
          isOn: _ramzanOn,
          badge: _isRamzan ? '🌙' : 'AUTO',
          badgeHighlight: _isRamzan,
          onTap: _azanOn ? _toggleRamzan : null,
          activeColor: AppColors.gold2,
          activeBg: const Color(0xFF130F00),
          activeBorder: AppColors.gold,
        ),
      ],
    );
  }

  Widget _buildPrayerList() {
    if (_loadingPrayers) {
      return const Center(
        child: Padding(
            padding: EdgeInsets.all(20),
            child: CircularProgressIndicator(color: AppColors.gold)),
      );
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(_error!,
              style: const TextStyle(color: AppColors.red, fontSize: 13),
              textAlign: TextAlign.center),
        ),
      );
    }

    final nowMins = _now.hour * 60 + _now.minute;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      child: Column(
        key: ValueKey(_fiqa),
        children: _prayers.asMap().entries.map((e) {
          final i = e.key;
          final p = e.value;
          final isNext = i == _nextIdx;
          final isPassed = p.totalMinutes < nowMins && !isNext;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: PrayerRowWidget(
              prayer: p,
              isNext: isNext,
              isPassed: isPassed,
              showToggle: _azanOn,
              onToggle: () => _togglePrayerAlarm(p),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDivider() => Container(height: 1, color: AppColors.border);

  Widget _buildSectionLabel(String text) => Text(text,
      style: const TextStyle(
          fontSize: 9,
          letterSpacing: 2.5,
          color: AppColors.muted,
          fontWeight: FontWeight.w700));

  Widget _buildTestAlarmSection() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF30363D)),
      ),
      child: Row(
        children: [
          const Text('🧪', style: TextStyle(fontSize: 20)),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Test Alarm',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
                Text('Fire a test azan after N minutes',
                    style: TextStyle(color: AppColors.muted, fontSize: 11)),
              ],
            ),
          ),
          GestureDetector(
            onTap: _showTestAlarmDialog,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.gold.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border:
                    Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
              ),
              child: const Text('Set Test',
                  style: TextStyle(
                      color: AppColors.gold,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showTestAlarmDialog() async {
    int? selectedMins;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF161B22),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        final controller = TextEditingController();
        return Padding(
          padding: EdgeInsets.only(
              left: 24,
              right: 24,
              top: 24,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('🧪 Test Alarm',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              const Text('Enter minutes from now to fire test azan:',
                  style: TextStyle(color: AppColors.muted, fontSize: 13)),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                autofocus: true,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  hintText: '1',
                  hintStyle: const TextStyle(color: AppColors.muted),
                  suffixText: 'minutes',
                  suffixStyle:
                      const TextStyle(color: AppColors.muted, fontSize: 14),
                  filled: true,
                  fillColor: const Color(0xFF0D1117),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.border)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: AppColors.gold, width: 2)),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.muted,
                        side: const BorderSide(color: AppColors.border),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        final mins = int.tryParse(controller.text.trim());
                        if (mins == null || mins <= 0) return;
                        selectedMins = mins;
                        Navigator.pop(ctx);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.gold,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Set Alarm',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );

    if (selectedMins != null) await _scheduleTestAlarm(selectedMins!);
  }

  Future<void> _scheduleTestAlarm(int minutes) async {
    final triggerTime = DateTime.now().add(Duration(minutes: minutes));
    const testId = 98;

    try {
      const platform = MethodChannel('azan_service_channel');
      await platform.invokeMethod('scheduleNativeAlarm', {
        'prayer_name': 'Test',
        'alarm_id': testId,
        'trigger_ms': triggerTime.millisecondsSinceEpoch,
      });
    } catch (_) {}

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '✅ Test alarm set for '
            '${triggerTime.hour.toString().padLeft(2, '0')}:'
            '${triggerTime.minute.toString().padLeft(2, '0')} '
            '(in $minutes min) — kill app & lock phone!',
          ),
          backgroundColor: AppColors.green,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }
}

class _GpsDot extends StatefulWidget {
  final bool active;
  const _GpsDot({required this.active});
  @override
  State<_GpsDot> createState() => _GpsDotState();
}

class _GpsDotState extends State<_GpsDot> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl =
        AnimationController(vsync: this, duration: const Duration(seconds: 2))
          ..repeat(reverse: true);
    _anim = Tween<double>(begin: 1, end: 0.3)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active) return const SizedBox(width: 8, height: 8);
    return FadeTransition(
      opacity: _anim,
      child: Container(
        width: 8,
        height: 8,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.green,
          boxShadow: [BoxShadow(color: AppColors.green, blurRadius: 6)],
        ),
      ),
    );
  }
}
