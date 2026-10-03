import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';

const primary = Color(0xFF176B4D);
const accent = Color(0xFFF39A3D);
const cream = Color(0xFFFFF8EA);
const apiBase = String.fromEnvironment('JAYEK_API', defaultValue: 'http://10.0.2.2:3000/api/v1');

void main() => runApp(const RiderApp());

class RiderApi {
  String? token;
  String? refreshToken;
  Future<dynamic> call(String method, String path, {Map<String, dynamic>? body}) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
    final uri = Uri.parse('$apiBase$path');
    http.Response response;
    try {
      if (method == 'GET') {
        response = await http.get(uri, headers: headers).timeout(const Duration(seconds: 15));
      } else if (method == 'POST') {
        response = await http.post(uri, headers: headers, body: jsonEncode(body ?? {})).timeout(const Duration(seconds: 15));
      } else {
        response = await http.patch(uri, headers: headers, body: jsonEncode(body ?? {})).timeout(const Duration(seconds: 15));
      }
    } catch (_) {
      throw Exception('تعذر الاتصال بالخادم');
    }
    if (response.statusCode == 401 && refreshToken != null && !path.startsWith('/auth/')) { final ok=await refresh(); if(ok)return call(method,path,body:body); } if (response.statusCode == 401) throw Exception('جلسة الكابتن انتهت');
    if (response.statusCode >= 400) {
      String message = 'حدث خطأ';
      try {
        final data = jsonDecode(response.body);
        message = (data['message'] ?? message).toString();
      } catch (_) {}
      throw Exception(message);
    }
    return response.body.isEmpty ? <String, dynamic>{} : jsonDecode(response.body);
  }

  Future<dynamic> get(String path) => call('GET', path);
  Future<dynamic> post(String path, Map<String, dynamic> body) => call('POST', path, body: body);
  Future<dynamic> patch(String path, Map<String, dynamic> body) => call('PATCH', path, body: body);

  Future<bool> refresh() async {
    try { final r=await post('/auth/refresh',{'refreshToken':refreshToken}); token=r['accessToken']?.toString(); refreshToken=r['refreshToken']?.toString(); await save(); return token!=null; } catch(_) { token=null; refreshToken=null; await save(); return false; }
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    if (token == null) { await prefs.remove('riderToken'); } else { await prefs.setString('riderToken', token!); }
    if (refreshToken == null) { await prefs.remove('riderRefreshToken'); } else { await prefs.setString('riderRefreshToken', refreshToken!); }
  }

  Future<void> restore() async {
    final prefs = await SharedPreferences.getInstance();
    token = prefs.getString('riderToken');
    refreshToken = prefs.getString('riderRefreshToken');
  }
}

class RiderApp extends StatefulWidget {
  const RiderApp({super.key});
  @override State<RiderApp> createState() => _RiderAppState();
}

class _RiderAppState extends State<RiderApp> {
  final api = RiderApi();
  bool loading = true;
  @override void initState() { super.initState(); restore(); }
  Future<void> restore() async { await api.restore(); if (mounted) setState(() => loading = false); }
  Future<void> logout() async { api.token = null; api.refreshToken = null; await api.save(); if (mounted) setState(() {}); }
  @override Widget build(BuildContext context) {
    if (loading) return const MaterialApp(home: Scaffold(body: Center(child: CircularProgressIndicator())));
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'جايك كابتن',
      theme: ThemeData(useMaterial3: true, colorScheme: ColorScheme.fromSeed(seedColor: primary), scaffoldBackgroundColor: cream),
      home: api.token == null ? RiderLogin(api: api, onDone: () => setState(() {})) : RiderHome(api: api, onLogout: logout),
    );
  }
}

class RiderLogin extends StatefulWidget {
  final RiderApi api;
  final VoidCallback onDone;
  const RiderLogin({super.key, required this.api, required this.onDone});
  @override State<RiderLogin> createState() => _RiderLoginState();
}

class _RiderLoginState extends State<RiderLogin> {
  final phone = TextEditingController(text: '01000000003');
  final code = TextEditingController(text: '1234');
  String? challenge;
  String message = '';
  bool busy = false;

  Future<void> request() async {
    setState(() => busy = true);
    try {
      final data = await widget.api.post('/auth/request-otp', {'phone': phone.text.trim()});
      challenge = data['challengeId']?.toString();
      if (data['devCode'] != null) code.text = data['devCode'].toString();
      message = 'تم إرسال الرمز';
    } catch (e) {
      message = e.toString().replaceFirst('Exception: ', '');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> verify() async {
    if (challenge == null) { await request(); return; }
    setState(() => busy = true);
    try {
      final data = await widget.api.post('/auth/verify-otp', {
        'challengeId': challenge, 'phone': phone.text.trim(), 'code': code.text.trim(), 'name': 'كابتن جايك',
      });
      final user = data['user'];
      if (user is! Map || user['role'] != 'RIDER') throw Exception('هذا الحساب ليس حساب كابتن');
      widget.api.token = data['accessToken']?.toString();
      widget.api.refreshToken = data['refreshToken']?.toString();
      await widget.api.save();
      widget.onDone();
    } catch (e) {
      message = e.toString().replaceFirst('Exception: ', '');
      if (mounted) setState(() {});
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override void dispose() { phone.dispose(); code.dispose(); super.dispose(); }

  @override Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(children: [
            const Icon(Icons.delivery_dining, size: 90, color: primary),
            const Text('جايك كابتن', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: primary)),
            const SizedBox(height: 24),
            TextField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'رقم الكابتن', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(controller: code, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'رمز التحقق', border: OutlineInputBorder())),
            const SizedBox(height: 14),
            SizedBox(width: double.infinity, height: 52, child: FilledButton(onPressed: busy ? null : verify, style: FilledButton.styleFrom(backgroundColor: primary), child: Text(challenge == null ? 'إرسال الرمز' : 'دخول'))),
            if (challenge != null) TextButton(onPressed: busy ? null : request, child: const Text('إرسال الرمز مرة أخرى')),
            if (message.isNotEmpty) Text(message),
          ]),
        ),
      ),
    ),
  );
}

class RiderHome extends StatefulWidget {
  final RiderApi api;
  final VoidCallback onLogout;
  const RiderHome({super.key, required this.api, required this.onLogout});
  @override State<RiderHome> createState() => _RiderHomeState();
}

class _RiderHomeState extends State<RiderHome> {
  List available = [];
  List active = [];
  Map<String, dynamic> me = {};
  Map<String, dynamic> earnings = {};
  bool online = false;
  bool loading = true;
  StreamSubscription<Position>? locationSub;

  @override void initState() { super.initState(); load(); }

  Future<void> load() async {
    try {
      final values = await Future.wait([
        widget.api.get('/rider/me'),
        widget.api.get('/rider/tasks/available'),
        widget.api.get('/rider/tasks/active'),
        widget.api.get('/rider/earnings?days=30'),
      ]);
      me = Map<String, dynamic>.from(values[0] as Map? ?? {});
      available = values[1] as List? ?? [];
      active = values[2] as List? ?? [];
      earnings = Map<String, dynamic>.from(values[3] as Map? ?? {});
      online = me['is_online'] == true;
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> setOnline(bool value) async {
    try { await widget.api.patch('/rider/online', {'online': value}); setState(() => online = value); }
    catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()))); }
  }

  Future<void> accept(String id) async {
    try { await widget.api.post('/rider/tasks/$id/accept', {}); await load(); }
    catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()))); }
  }

  Future<void> status(String id, String value) async {
    try { await widget.api.patch('/rider/orders/$id/status', {'status': value}); await load(); }
    catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()))); }
  }

  Future<void> sendCurrentLocation() async {
    try {
      if(!await Geolocator.isLocationServiceEnabled()) throw Exception('فعّل خدمة الموقع');
      var p=await Geolocator.checkPermission();
      if(p==LocationPermission.denied)p=await Geolocator.requestPermission();
      if(p==LocationPermission.denied||p==LocationPermission.deniedForever) throw Exception('اسمح بالموقع من إعدادات الهاتف');
      final pos=await Geolocator.getCurrentPosition(locationSettings:const LocationSettings(accuracy:LocationAccuracy.high,timeLimit:Duration(seconds:10)));
      await widget.api.patch('/rider/location', {'latitude':pos.latitude,'longitude':pos.longitude,'accuracy':pos.accuracy});
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تحديث موقعك الحالي')));
      await load();
    } catch(e) { if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ','')))); }
  }

  String label(String status) {
    const values = {'READY_FOR_PICKUP': 'جاهز للاستلام', 'ASSIGNED_RIDER': 'مُسند للكابتن', 'PICKED_UP': 'تم الاستلام', 'ON_THE_WAY': 'في الطريق', 'DELIVERED': 'تم التسليم'};
    return values[status] ?? status;
  }

  @override Widget build(BuildContext context) {
    if (loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('جايك كابتن', style: TextStyle(fontWeight: FontWeight.w900, color: primary)),
          actions: [
            IconButton(onPressed: sendDemoLocation, icon: const Icon(Icons.my_location, color: primary)),
            IconButton(onPressed: widget.onLogout, icon: const Icon(Icons.logout)),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: load,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(child: SwitchListTile(value: online, onChanged: setOnline, title: const Text('متاح لاستقبال الطلبات', style: TextStyle(fontWeight: FontWeight.w800)), subtitle: Text(online ? 'أنت أونلاين' : 'أنت أوفلاين'), secondary: const Icon(Icons.wifi_tethering, color: primary))),
              Card(child: ListTile(leading: const Icon(Icons.payments_outlined, color: primary), title: const Text('أرباح آخر 30 يوم'), subtitle: Text('${earnings['totalDeliveryFees'] ?? 0} جنيه • ${earnings['deliveryCount'] ?? 0} توصيل'))),
              const SizedBox(height: 12),
              const Text('طلبات متاحة', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
              if (available.isEmpty) const Padding(padding: EdgeInsets.all(20), child: Center(child: Text('لا توجد مهام متاحة حاليًا'))),
              for (final raw in available) _taskCard(Map<String, dynamic>.from(raw), available: true),
              const SizedBox(height: 16),
              const Text('مهامي الحالية', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
              if (active.isEmpty) const Padding(padding: EdgeInsets.all(20), child: Center(child: Text('لا توجد مهام نشطة'))),
              for (final raw in active) _taskCard(Map<String, dynamic>.from(raw), available: false),
            ],
          ),
        ),
      ),
    );
  }

  Widget _taskCard(Map<String, dynamic> task, {required bool available}) {
    final id = task['id'].toString();
    final statusValue = task['status'].toString();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${task['merchant_name'] ?? 'متجر'} • ${task['village'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 5),
          Text('الإجمالي: ${task['total'] ?? 0} جنيه • التوصيل: ${task['delivery_fee'] ?? 0} جنيه'),
          Text('الحالة: ${label(statusValue)}'),
          const SizedBox(height: 8),
          if (available)
            SizedBox(width: double.infinity, child: FilledButton(onPressed: () => accept(id), style: FilledButton.styleFrom(backgroundColor: primary), child: const Text('استلام المهمة')))
          else
            Wrap(spacing: 8, children: [
              if (statusValue == 'ASSIGNED_RIDER') FilledButton(onPressed: () => status(id, 'PICKED_UP'), style: FilledButton.styleFrom(backgroundColor: primary), child: const Text('استلمت الطلب')),
              if (statusValue == 'PICKED_UP') FilledButton(onPressed: () => status(id, 'ON_THE_WAY'), style: FilledButton.styleFrom(backgroundColor: primary), child: const Text('خرجت للتوصيل')),
              if (statusValue == 'ON_THE_WAY') FilledButton(onPressed: () => status(id, 'DELIVERED'), style: FilledButton.styleFrom(backgroundColor: primary), child: const Text('تم التسليم')),
            ]),
        ]),
      ),
    );
  }
}
