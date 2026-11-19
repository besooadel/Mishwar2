import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'api.dart';

const navy = Color(0xFF0F2A43), amber = Color(0xFFFFB400), grey = Color(0xFF5B6776);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Api.load();
  runApp(const RiderApp());
}

class RiderApp extends StatelessWidget {
  const RiderApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'مشوار',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          scaffoldBackgroundColor: const Color(0xFFF5F7FA),
          colorScheme: ColorScheme.fromSeed(seedColor: navy, primary: navy, secondary: amber),
          filledButtonTheme: FilledButtonThemeData(
              style: FilledButton.styleFrom(
                  backgroundColor: amber, foregroundColor: navy, minimumSize: const Size.fromHeight(56),
                  textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)))),
        ),
        builder: (c, w) => Directionality(textDirection: TextDirection.rtl, child: w!),
        home: Api.token == null ? const AuthPage() : const HomePage(),
      );
}

void toast(BuildContext c, Object m) =>
    ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text('$m')));

// ---------------- تسجيل الدخول / إنشاء حساب ----------------
class AuthPage extends StatefulWidget {
  const AuthPage({super.key});
  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final name = TextEditingController(), phone = TextEditingController(), pass = TextEditingController();
  bool register = false, busy = false;

  Future<void> submit() async {
    setState(() => busy = true);
    try {
      final d = await Api.call(register ? 'register' : 'login',
          body: {'name': name.text, 'phone': phone.text, 'password': pass.text, 'role': 'rider'});
      if (d['role'] != 'rider') throw 'الحساب ده مش حساب راكب';
      await Api.save(d['token']);
      if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomePage()));
    } catch (e) {
      if (mounted) toast(context, e);
    }
    if (mounted) setState(() => busy = false);
  }

  Widget field(TextEditingController c, String l, {bool secret = false, TextInputType? t}) => Padding(
      padding: const EdgeInsets.only(top: 12),
      child: TextField(
          controller: c, obscureText: secret, keyboardType: t,
          decoration: InputDecoration(labelText: l, filled: true, fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))));

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
            child: ListView(padding: const EdgeInsets.all(24), children: [
          const SizedBox(height: 40),
          const Text('مشوار.', style: TextStyle(fontSize: 40, fontWeight: FontWeight.w800, color: navy)),
          const SizedBox(height: 4),
          Text(register ? 'اعمل حساب جديد' : 'سجّل دخولك', style: const TextStyle(color: grey, fontSize: 16)),
          if (register) field(name, 'الاسم'),
          field(phone, 'رقم الموبايل', t: TextInputType.phone),
          field(pass, 'كلمة السر', secret: true),
          const SizedBox(height: 20),
          FilledButton(onPressed: busy ? null : submit, child: Text(register ? 'إنشاء حساب' : 'دخول')),
          TextButton(onPressed: () => setState(() => register = !register),
              child: Text(register ? 'عندي حساب' : 'مستخدم جديد؟ سجّل')),
        ])),
      );
}

// ---------------- الرئيسية ----------------
class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final dest = TextEditingController();
  List banners = [];
  List types = [];
  int? sel;
  Position? pos;
  Location? to;
  String? info;

  @override
  void initState() {
    super.initState();
    Api.call('banners', q: {'placement': 'home'}).then((d) => setState(() => banners = d)).catchError((e) {
      if (e == 'سجّل دخول') logout();
    });
    Api.call('vehicle_types').then((d) => setState(() => types = d));
  }

  Future<void> logout() async {
    await Api.save(null);
    if (mounted) Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const AuthPage()), (_) => false);
  }

  Future<void> getQuote() async {
    try {
      var p = await Geolocator.checkPermission();
      if (p == LocationPermission.denied) p = await Geolocator.requestPermission();
      if (p == LocationPermission.denied || p == LocationPermission.deniedForever) throw 'فعّل صلاحية الموقع';
      pos = await Geolocator.getCurrentPosition();
      to = (await locationFromAddress(dest.text)).first;
      final d = await Api.call('quote', body: {'plat': pos!.latitude, 'plng': pos!.longitude, 'dlat': to!.latitude, 'dlng': to!.longitude});
      setState(() {
        types = d['types'];
        sel = types.first['id'];
        info = '${d['km']} كم · حوالي ${d['minutes']} دقيقة';
      });
    } catch (e) {
      if (mounted) toast(context, e is String ? e : 'مش قادر أحدد الوجهة، جرّب عنوان أوضح');
    }
  }

  Future<void> request() async {
    try {
      final d = await Api.call('trip_request', body: {
        'vehicle_type_id': sel, 'plat': pos!.latitude, 'plng': pos!.longitude, 'paddr': 'موقعي الحالي',
        'dlat': to!.latitude, 'dlng': to!.longitude, 'daddr': dest.text});
      if (mounted) Navigator.push(context, MaterialPageRoute(builder: (_) => TripPage(id: d['id'])));
    } catch (e) {
      if (mounted) toast(context, e);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('مشوار', style: TextStyle(fontWeight: FontWeight.w800)), actions: [
          IconButton(tooltip: 'محفظتي', icon: const Icon(Icons.account_balance_wallet_outlined),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WalletPage()))),
          IconButton(tooltip: 'خروج', icon: const Icon(Icons.logout), onPressed: logout),
        ]),
        body: ListView(padding: const EdgeInsets.all(20), children: [
          const Text('عايز تروح فين النهاردة؟', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
          const SizedBox(height: 14),
          if (banners.isNotEmpty)
            SizedBox(height: 150, child: PageView(children: [
              for (final b in banners)
                Container(margin: const EdgeInsets.only(left: 8), padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(color: amber, borderRadius: BorderRadius.circular(20)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(color: navy, borderRadius: BorderRadius.circular(8)),
                          child: const Text('إعلان', style: TextStyle(color: Colors.white, fontSize: 12))),
                      Text(b['title'] ?? '', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: navy)),
                      Text(b['advertiser'] ?? '', style: const TextStyle(color: navy)),
                    ]))
            ])),
          const SizedBox(height: 16),
          TextField(controller: dest, textInputAction: TextInputAction.search, onSubmitted: (_) => getQuote(),
              decoration: InputDecoration(hintText: 'رايح فين؟', filled: true, fillColor: Colors.white,
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: IconButton(tooltip: 'احسب السعر', icon: const Icon(Icons.arrow_back), onPressed: getQuote),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none))),
          if (info != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(info!, style: const TextStyle(color: grey))),
          const SizedBox(height: 16),
          const Text('اختار مشوارك', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Row(children: [
            for (final t in types)
              Expanded(child: GestureDetector(
                  onTap: t['est_fare'] == null ? null : () => setState(() => sel = t['id']),
                  child: Container(margin: const EdgeInsets.all(4), padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: sel == t['id'] ? navy : Colors.transparent, width: 2)),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(t['name_ar'], style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                        Text(t['est_fare'] == null ? 'اكتب وجهتك' : '${t['est_fare']} جنيه', style: const TextStyle(color: grey)),
                      ]))))
          ]),
          const SizedBox(height: 20),
          FilledButton(onPressed: sel != null && to != null ? request : null, child: const Text('اطلب مشوار')),
        ]),
      );
}

// ---------------- تتبع المشوار ----------------
class TripPage extends StatefulWidget {
  final String id;
  const TripPage({super.key, required this.id});
  @override
  State<TripPage> createState() => _TripPageState();
}

class _TripPageState extends State<TripPage> {
  Map? t;
  Timer? timer;
  static const label = {
    'requested': 'بندوّر على كابتن قريب منك…', 'accepted': 'الكابتن في الطريق إليك',
    'arrived': 'الكابتن وصل', 'in_progress': 'المشوار شغال', 'completed': 'وصلت بالسلامة', 'cancelled': 'المشوار اتلغى'};

  @override
  void initState() {
    super.initState();
    poll();
    timer = Timer.periodic(const Duration(seconds: 4), (_) => poll());
  }

  Future<void> poll() async {
    try {
      final d = await Api.call('trip', q: {'id': widget.id});
      if (mounted) setState(() => t = d);
      if (d['status'] == 'completed' || d['status'] == 'cancelled') timer?.cancel();
    } catch (_) {}
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = t?['status'];
    return Scaffold(
      appBar: AppBar(title: const Text('مشوارك')),
      body: t == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(padding: const EdgeInsets.all(20), children: [
              Text(label[s] ?? '', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
              const SizedBox(height: 16),
              if (t!['captain_name'] != null)
                Card(child: ListTile(title: Text('${t!['captain_name']}'),
                    subtitle: Text('${t!['model'] ?? ''} ${t!['color'] ?? ''} · ${t!['plate'] ?? ''}\n${t!['captain_phone']}'), isThreeLine: true)),
              Card(child: ListTile(title: const Text('إلى'), subtitle: Text('${t!['dropoff_address']}'))),
              Card(child: ListTile(
                  title: Text(s == 'completed' ? 'الأجرة النهائية' : 'السعر التقريبي'),
                  subtitle: const Text('الدفع كاش للكابتن (بعد خصم رصيد محفظتك لو موجود)'),
                  trailing: Text('${t!['fare'] ?? t!['est_fare']} ج', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)))),
              const SizedBox(height: 16),
              if (['requested', 'accepted', 'arrived'].contains(s))
                OutlinedButton(
                    style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                    onPressed: () async {
                      await Api.call('trip_cancel', body: {'id': widget.id});
                      poll();
                    },
                    child: const Text('إلغاء المشوار')),
              if (s == 'completed' || s == 'cancelled')
                FilledButton(onPressed: () => Navigator.pop(context), child: const Text('تمام')),
            ]),
    );
  }
}

// ---------------- المحفظة والعروض ----------------
class WalletPage extends StatefulWidget {
  const WalletPage({super.key});
  @override
  State<WalletPage> createState() => _WalletPageState();
}

class _WalletPageState extends State<WalletPage> {
  Map? w;
  List offers = [];
  static const tx = {'topup': 'إضافة لرصيدك', 'trip_payment': 'خصم من مشوار', 'refund': 'استرداد', 'adjustment': 'تعديل'};

  @override
  void initState() {
    super.initState();
    Api.call('wallet').then((d) => setState(() => w = d));
    Api.call('offers').then((d) => setState(() => offers = d));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('محفظتي')),
        body: w == null
            ? const Center(child: CircularProgressIndicator())
            : ListView(padding: const EdgeInsets.all(20), children: [
                Container(padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(color: navy, borderRadius: BorderRadius.circular(16)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('رصيدك', style: TextStyle(color: Color(0xFFC9D3DE))),
                      Text('${w!['balance']} جنيه', style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w800)),
                      const Text('باقي الأجرة بيتحفظ هنا وبيتخصم من مشوارك الجاي', style: TextStyle(color: Color(0xFFC9D3DE), fontSize: 13)),
                    ])),
                if (offers.isNotEmpty) ...[
                  const Padding(padding: EdgeInsets.only(top: 20, bottom: 8), child: Text('عروض ليك', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
                  for (final o in offers)
                    Card(color: o['kind'] == 'offer' ? amber : Colors.white,
                        child: ListTile(title: Text('${o['title']}', style: const TextStyle(fontWeight: FontWeight.w800)),
                            subtitle: Text('${o['body'] ?? ''}${o['discount_percent'] != null ? '\nخصم ${o['discount_percent']}%' : ''}'))),
                ],
                const Padding(padding: EdgeInsets.only(top: 20, bottom: 8), child: Text('آخر الحركات', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
                for (final x in w!['transactions'])
                  ListTile(title: Text(tx[x['type']] ?? '${x['type']}'), subtitle: Text('${x['note'] ?? ''}'),
                      trailing: Text('${x['amount']} ج', style: TextStyle(fontWeight: FontWeight.w800, color: double.parse('${x['amount']}') < 0 ? Colors.red.shade700 : navy))),
              ]),
      );
}
