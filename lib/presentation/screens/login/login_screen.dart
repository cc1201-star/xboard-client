import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xboard_client/core/theme/app_theme.dart';
import 'package:xboard_client/core/constants/app_constants.dart';
import 'package:xboard_client/core/utils/platform_utils.dart';
import 'package:xboard_client/presentation/providers/auth_provider.dart';
import 'package:xboard_client/presentation/widgets/custom_title_bar.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> with SingleTickerProviderStateMixin {
  String _mode = 'signup';

  final _accountController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _showPw = false;
  bool _isLoading = false;
  String? _error;

  int _colorIndex = 0;
  Timer? _colorTimer;

  // 0.0 = signup (彩色在左), 1.0 = signin (彩色在右)
  late AnimationController _anim;

  static const _colors = [
    Color(0xFF0A3161), Color(0xFF1A4D3D), Color(0xFF2C3E50),
    Color(0xFF3D1A4D), Color(0xFF4A1A1A), Color(0xFF3E2A1C),
  ];

  static const _curve = Cubic(0.6, 0.01, -0.05, 0.9);

  @override
  void initState() {
    super.initState();
    _colorTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (mounted) setState(() => _colorIndex = (_colorIndex + 1) % _colors.length);
    });
    _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
  }

  @override
  void dispose() {
    _colorTimer?.cancel();
    _anim.dispose();
    _accountController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _goSignin() {
    setState(() { _mode = 'signin'; _error = null; _passwordController.clear(); });
    _anim.animateTo(1.0, curve: _curve);
  }

  void _goSignup() {
    setState(() { _mode = 'signup'; _error = null; _passwordController.clear(); });
    _anim.animateTo(0.0, curve: _curve);
  }

  Future<void> _saveSidebarColor() async {
    // 只写 SharedPreferences，不更新 provider，避免触发 rebuild 导致页面闪回
    final prefs = await SharedPreferences.getInstance();
    final hex = '#${(_colors[_colorIndex].value & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
    await prefs.setString('sidebar_color', hex);
  }

  Future<void> _handleSignin() async {
    final account = _accountController.text.trim();
    final password = _passwordController.text.trim();
    if (account.isEmpty || password.isEmpty) { setState(() => _error = '请填写所有字段'); return; }
    setState(() { _isLoading = true; _error = null; });
    try {
      _saveSidebarColor(); // fire and forget，不 await
      await ref.read(authStateProvider.notifier).login(AppConstants.serverUrl, account, password);
      final s = ref.read(authStateProvider);
      if (s.isAuthenticated) return;
      if (mounted) setState(() { _isLoading = false; _error = s.error ?? '账号或密码错误'; });
    } catch (_) {
      if (mounted) setState(() { _isLoading = false; _error = '账号或密码错误'; });
    }
  }

  Future<void> _handleSignup() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();
    if (username.isEmpty || password.isEmpty) { setState(() => _error = '请填写所有字段'); return; }
    if (password.length < 8) { setState(() => _error = '密码至少需要 8 个字符'); return; }
    setState(() { _isLoading = true; _error = null; });
    try {
      _saveSidebarColor(); // fire and forget
      await ref.read(authStateProvider.notifier).register(AppConstants.serverUrl, username, password);
      final s = ref.read(authStateProvider);
      if (s.isAuthenticated) return;
      if (s.error != null) {
        if (mounted) setState(() { _isLoading = false; _error = s.error ?? '注册失败'; });
      } else {
        _accountController.text = username;
        if (mounted) setState(() => _isLoading = false);
        _goSignin();
      }
    } catch (_) {
      if (mounted) setState(() { _isLoading = false; _error = '注册失败'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isWide = size.width > 768;
    return Scaffold(body: Column(children: [
      if (isDesktopPlatform) const CustomTitleBar(),
      Expanded(child: AnimatedBuilder(animation: _anim, builder: (context, _) {
        final t = _anim.value;
        return isWide ? _desktop(size, t) : _mobile(size, t);
      })),
    ]));
  }

  // ───── Desktop: 左右穿梭 ─────

  Widget _desktop(Size size, double t) {
    final halfW = size.width / 2;
    return Stack(children: [
      // 白色面板 (下层): signup时在右(50%), signin时在左(0%)
      Positioned(
        left: (1 - t) * halfW, top: 0, width: halfW, height: size.height,
        child: Container(color: Colors.white,
          child: _mode == 'signup' ? _signupForm(true) : _signinForm(true)),
      ),
      // 彩色面板 (上层 z-10): signup时在左(0%), signin时在右(50%)
      Positioned(
        left: t * halfW, top: 0, width: halfW, height: size.height,
        child: AnimatedContainer(
          duration: const Duration(seconds: 1), curve: Curves.easeInOut,
          color: _colors[_colorIndex],
          child: _mode == 'signup'
              ? _colorPanel('欢迎来到 Xboard', '使用用户名和密码登录', '去登录', _goSignin)
              : _colorPanel('你好，世界', '立即注册，畅享我们的服务', '去注册', _goSignup),
        ),
      ),
    ]);
  }

  // ───── Mobile: 上下穿梭 ─────

  Widget _mobile(Size size, double t) {
    final halfH = size.height / 2;
    return Stack(children: [
      // 白色面板 (下层)
      Positioned(
        left: 0, top: (1 - t) * halfH, width: size.width, height: halfH,
        child: Container(color: Colors.white,
          child: _mode == 'signup' ? _signupForm(false) : _signinForm(false)),
      ),
      // 彩色面板 (上层)
      Positioned(
        left: 0, top: t * halfH, width: size.width, height: halfH,
        child: AnimatedContainer(
          duration: const Duration(seconds: 1), curve: Curves.easeInOut,
          color: _colors[_colorIndex],
          child: _mode == 'signup'
              ? _colorPanel('欢迎来到 Xboard', '使用用户名和密码登录', '去登录', _goSignin, compact: true)
              : _colorPanel('你好，世界', '立即注册，畅享我们的服务', '去注册', _goSignup, compact: true),
        ),
      ),
    ]);
  }

  // ───── 彩色面板内容 ─────

  Widget _colorPanel(String title, String sub, String btn, VoidCallback onTap, {bool compact = false}) {
    return Center(child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(title, style: TextStyle(fontSize: compact ? 22 : 28, fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 8),
        Text(sub, style: TextStyle(fontSize: compact ? 12 : 14, color: Colors.white70)),
        const SizedBox(height: 24),
        SizedBox(width: 144, height: 40, child: OutlinedButton(
          onPressed: onTap,
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Colors.white, width: 2),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            foregroundColor: Colors.white,
          ),
          child: Text(btn, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        )),
      ],
    ));
  }

  // ───── 注册表单 ─────

  Widget _signupForm(bool desktop) {
    final ratio = desktop ? 0.5 : 0.75;
    return Center(child: SingleChildScrollView(child: SizedBox(
      width: double.infinity,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('创建账户', textAlign: TextAlign.center,
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppColors.gray900)),
        const SizedBox(height: 6),
        const Text('使用用户名注册', textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12.5, color: AppColors.gray400)),
        const SizedBox(height: 16),
        if (_error != null && _mode == 'signup') _errorBox(_error!),
        LayoutBuilder(builder: (_, c) {
          final w = c.maxWidth * ratio;
          return Column(children: [
            SizedBox(width: w, child: _input(_usernameController, '用户名')),
            const SizedBox(height: 12),
            SizedBox(width: w, child: _pwInput('密码（至少 8 位）')),
            const SizedBox(height: 24),
            _submitBtn('注册', _handleSignup),
          ]);
        }),
      ]),
    )));
  }

  // ───── 登录表单 ─────

  Widget _signinForm(bool desktop) {
    final ratio = desktop ? 0.5 : 0.75;
    return Center(child: SingleChildScrollView(child: SizedBox(
      width: double.infinity,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('登录', textAlign: TextAlign.center,
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppColors.gray900)),
        const SizedBox(height: 6),
        const Text('使用用户名和密码登录', textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12.5, color: AppColors.gray400)),
        const SizedBox(height: 16),
        if (_error != null && _mode == 'signin') _errorBox(_error!),
        LayoutBuilder(builder: (_, c) {
          final w = c.maxWidth * ratio;
          return Column(children: [
            SizedBox(width: w, child: _input(_accountController, '用户名或邮箱')),
            const SizedBox(height: 12),
            SizedBox(width: w, child: _pwInput('请输入密码')),
            const SizedBox(height: 8),
            SizedBox(width: w, child: Align(
              alignment: Alignment.centerRight,
              child: GestureDetector(onTap: () {},
                child: const Text('忘记密码？', style: TextStyle(fontSize: 12, color: AppColors.gray400))),
            )),
            const SizedBox(height: 24),
            _submitBtn('登录', _handleSignin),
          ]);
        }),
      ]),
    )));
  }

  // ───── 组件 ─────

  Widget _errorBox(String msg) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: const Color(0x1FFF453A), borderRadius: BorderRadius.circular(8)),
      child: Text(msg, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFFFF6B6B), fontSize: 12)),
    ),
  );

  InputDecoration _deco(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: AppColors.gray400, fontSize: 13.5),
    filled: true, fillColor: AppColors.gray50,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.gray200)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.gray200)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFFF6B6B), width: 1)),
  );

  Widget _input(TextEditingController c, String hint) => SizedBox(height: 40,
    child: TextField(controller: c, enabled: !_isLoading,
      style: const TextStyle(fontSize: 13.5, color: AppColors.gray900), decoration: _deco(hint)));

  Widget _pwInput(String hint) => SizedBox(height: 40,
    child: TextField(
      controller: _passwordController, enabled: !_isLoading, obscureText: !_showPw,
      onSubmitted: (_) { _mode == 'signin' ? _handleSignin() : _handleSignup(); },
      style: const TextStyle(fontSize: 13.5, color: AppColors.gray900),
      decoration: _deco(hint).copyWith(
        suffixIcon: GestureDetector(onTap: () => setState(() => _showPw = !_showPw),
          child: Icon(_showPw ? Icons.visibility_outlined : Icons.visibility_off_outlined,
            color: AppColors.gray400, size: 16)),
      ),
    ));

  Widget _submitBtn(String text, VoidCallback onTap) => SizedBox(width: 160, height: 42,
    child: ElevatedButton(
      onPressed: _isLoading ? null : onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: _colors[_colorIndex], foregroundColor: Colors.white,
        disabledBackgroundColor: _colors[_colorIndex].withValues(alpha: 0.6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      ),
      child: _isLoading
          ? const Text('...', style: TextStyle(fontSize: 14, color: Colors.white))
          : Text(text, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 1)),
    ));
}
