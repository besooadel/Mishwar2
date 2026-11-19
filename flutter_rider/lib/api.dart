import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const apiBase = 'https://YOUR-DOMAIN.com/api.php'; // غيّره لرابط موقعك

class Api {
  static String? token;
  static Future<void> load() async =>
      token = (await SharedPreferences.getInstance()).getString('t');
  static Future<void> save(String? t) async {
    token = t;
    final p = await SharedPreferences.getInstance();
    t == null ? await p.remove('t') : await p.setString('t', t);
  }

  static Future<dynamic> call(String r, {Map<String, dynamic>? body, Map<String, String>? q}) async {
    final u = Uri.parse(apiBase).replace(queryParameters: {'r': r, ...?q});
    final h = {'Content-Type': 'application/json', if (token != null) 'Authorization': 'Bearer $token'};
    final res = body == null ? await http.get(u, headers: h) : await http.post(u, headers: h, body: jsonEncode(body));
    final d = jsonDecode(utf8.decode(res.bodyBytes));
    if (res.statusCode >= 400) throw (d is Map ? d['error'] : null) ?? 'حصل خطأ';
    return d;
  }
}
