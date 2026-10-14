import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

/// PATCHED(allow-self-signed)：允许自签名 / 不可信 HTTPS 证书。
///
/// 用途：连接自建 HTTPS、反向代理、内网穿透（樱花 frp / cpolar 等）时，
/// 证书常常是自签的，浏览器能点「继续访问」，但 App 默认会直接拒绝。
/// 打开这个开关后，本 App 的所有 HTTPS 请求（dio、http、SSE、图片）都会放行。
///
/// 实现方式：dart:io 的全局钩子 [HttpOverrides.global]。
/// dio / package:http / SSE 底层都走 dart:io 的 HttpClient，
/// 所以只需在 main() 里装一次，就覆盖全部网络层。
/// 断言里读取开关的**当前值**，因此改开关后立即生效，无需重建客户端。
class TlsPolicy {
  TlsPolicy._();

  /// SharedPreferences 里的键名
  static const String prefsKey = 'allow_insecure_tls';

  static bool _allowInsecureTls = false;

  /// 当前是否允许不可信证书
  static bool get allowInsecureTls => _allowInsecureTls;

  /// 启动时读取一次（默认关闭 = 保持严格校验）
  static Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _allowInsecureTls = prefs.getBool(prefsKey) ?? false;
    } catch (_) {
      _allowInsecureTls = false;
    }
  }

  /// 设置开关并持久化
  static Future<void> setAllowInsecureTls(bool value) async {
    _allowInsecureTls = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(prefsKey, value);
    } catch (_) {
      // 存储失败不影响本次会话中的生效
    }
  }

  /// 在 main() 里调用一次即可全局生效
  static void install() {
    HttpOverrides.global = _TlsOverrides();
  }
}

class _TlsOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = super.createHttpClient(context);
    client.badCertificateCallback =
        (X509Certificate cert, String host, int port) => TlsPolicy.allowInsecureTls;
    return client;
  }
}
