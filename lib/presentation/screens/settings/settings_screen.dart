import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xboard_client/core/theme/app_theme.dart';
import 'package:xboard_client/presentation/providers/auth_provider.dart';
import 'package:xboard_client/presentation/providers/user_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});
  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  // Password
  final _oldPwdCtrl = TextEditingController();
  final _newPwdCtrl = TextEditingController();
  final _confirmPwdCtrl = TextEditingController();
  bool _savingPwd = false;
  String? _pwdMsg;
  bool _pwdSuccess = false;

  // Email
  final _emailCtrl = TextEditingController();
  final _emailCodeCtrl = TextEditingController();
  int _cooldown = 0;
  Timer? _cooldownTimer;
  bool _bindingEmail = false;
  String? _emailMsg;
  bool _emailSuccess = false;

  // Sessions
  List<dynamic> _sessions = [];
  bool _loadingSessions = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(userProvider.notifier).fetchUser();
      _fetchSessions();
    });
  }

  @override
  void dispose() {
    _oldPwdCtrl.dispose();
    _newPwdCtrl.dispose();
    _confirmPwdCtrl.dispose();
    _emailCtrl.dispose();
    _emailCodeCtrl.dispose();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  Future<void> _changePassword() async {
    if (_newPwdCtrl.text != _confirmPwdCtrl.text) {
      setState(() { _pwdMsg = '两次输入的密码不一致'; _pwdSuccess = false; });
      return;
    }
    if (_newPwdCtrl.text.length < 6) {
      setState(() { _pwdMsg = '密码长度至少为6个字符'; _pwdSuccess = false; });
      return;
    }

    final client = ref.read(apiClientProvider);
    if (client == null) return;
    setState(() { _savingPwd = true; _pwdMsg = null; });
    try {
      await client.changePassword(_oldPwdCtrl.text, _newPwdCtrl.text);
      _oldPwdCtrl.clear(); _newPwdCtrl.clear(); _confirmPwdCtrl.clear();
      setState(() { _savingPwd = false; _pwdMsg = '密码修改成功'; _pwdSuccess = true; });
    } catch (_) {
      setState(() { _savingPwd = false; _pwdMsg = '密码修改失败'; _pwdSuccess = false; });
    }
  }

  Future<void> _sendEmailCode() async {
    if (_emailCtrl.text.isEmpty) return;
    final client = ref.read(apiClientProvider);
    if (client == null) return;
    try {
      await client.sendEmailVerify(_emailCtrl.text);
      setState(() => _cooldown = 60);
      _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (_cooldown <= 0) { t.cancel(); return; }
        setState(() => _cooldown--);
      });
    } catch (_) {
      setState(() { _emailMsg = '发送验证码失败'; _emailSuccess = false; });
    }
  }

  Future<void> _bindEmail() async {
    if (_emailCtrl.text.isEmpty || _emailCodeCtrl.text.isEmpty) return;
    final client = ref.read(apiClientProvider);
    if (client == null) return;
    setState(() { _bindingEmail = true; _emailMsg = null; });
    try {
      await client.bindEmail(_emailCtrl.text, _emailCodeCtrl.text);
      await ref.read(userProvider.notifier).fetchUser();
      setState(() { _bindingEmail = false; _emailMsg = '邮箱绑定成功'; _emailSuccess = true; });
    } catch (_) {
      setState(() { _bindingEmail = false; _emailMsg = '邮箱绑定失败'; _emailSuccess = false; });
    }
  }

  Future<void> _toggleNotification(String field, bool value) async {
    final client = ref.read(apiClientProvider);
    if (client == null) return;
    try {
      await client.updateUser({field: value ? 1 : 0});
      await ref.read(userProvider.notifier).fetchUser();
    } catch (_) {}
  }

  Future<void> _fetchSessions() async {
    final client = ref.read(apiClientProvider);
    if (client == null) return;
    try {
      final resp = await client.getActiveSessions();
      setState(() { _sessions = resp.data['data'] as List? ?? []; _loadingSessions = false; });
    } catch (_) {
      setState(() => _loadingSessions = false);
    }
  }

  Future<void> _removeSession(String sessionId) async {
    final client = ref.read(apiClientProvider);
    if (client == null) return;
    try {
      await client.removeActiveSession(sessionId);
      await _fetchSessions();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = ref.watch(userProvider).user;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('设置', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold,
          color: isDark ? Colors.white : AppColors.gray900)),
        const SizedBox(height: 24),

        // Profile section
        _buildCard(isDark, children: [
          Text('个人信息', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : AppColors.gray900)),
          const SizedBox(height: 16),
          Row(children: [
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(shape: BoxShape.circle, color: Theme.of(context).colorScheme.primary),
              child: Center(child: Text(
                (user?.username ?? user?.email ?? 'U').substring(0, 1).toUpperCase(),
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white))),
            ),
            const SizedBox(width: 16),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(user?.username ?? user?.email ?? '', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500,
                color: isDark ? Colors.white : AppColors.gray900)),
              const SizedBox(height: 2),
              if (user?.email != null && user!.email.isNotEmpty)
                Text(user.email, style: TextStyle(fontSize: 14, color: isDark ? AppColors.gray400 : AppColors.gray500))
              else
                Text('未绑定邮箱', style: TextStyle(fontSize: 14, color: AppColors.warning)),
            ]),
          ]),
        ]),
        const SizedBox(height: 24),

        // Change password
        _buildCard(isDark, children: [
          Text('修改密码', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : AppColors.gray900)),
          const SizedBox(height: 16),
          ConstrainedBox(constraints: const BoxConstraints(maxWidth: 448), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _inputLabel('当前密码', isDark),
            const SizedBox(height: 4),
            _passwordField(_oldPwdCtrl, isDark),
            const SizedBox(height: 16),
            _inputLabel('新密码', isDark),
            const SizedBox(height: 4),
            _passwordField(_newPwdCtrl, isDark),
            const SizedBox(height: 16),
            _inputLabel('确认新密码', isDark),
            const SizedBox(height: 4),
            _passwordField(_confirmPwdCtrl, isDark),
            if (_pwdMsg != null) ...[
              const SizedBox(height: 12),
              Text(_pwdMsg!, style: TextStyle(fontSize: 14,
                color: _pwdSuccess ? AppColors.success : AppColors.error)),
            ],
            const SizedBox(height: 16),
            SizedBox(height: 44, child: ElevatedButton(
              onPressed: _savingPwd ? null : _changePassword,
              style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.primary, foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: Text(_savingPwd ? '保存中...' : '修改密码'),
            )),
          ])),
        ]),
        const SizedBox(height: 24),

        // Bind email (only if not bound)
        if (user?.email == null || user!.email.isEmpty) ...[
          _buildCard(isDark, children: [
            Text('绑定邮箱', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : AppColors.gray900)),
            const SizedBox(height: 16),
            ConstrainedBox(constraints: const BoxConstraints(maxWidth: 448), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: TextField(controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(hintText: 'you@example.com',
                    filled: true, fillColor: isDark ? AppColors.gray700 : AppColors.gray100,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
                  style: TextStyle(fontSize: 14, color: isDark ? Colors.white : AppColors.gray900))),
                const SizedBox(width: 8),
                SizedBox(height: 48, child: ElevatedButton(
                  onPressed: (_cooldown > 0 || _emailCtrl.text.isEmpty) ? null : _sendEmailCode,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? AppColors.gray600 : AppColors.gray200,
                    foregroundColor: isDark ? AppColors.gray200 : AppColors.gray700,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: Text(_cooldown > 0 ? '${_cooldown}秒' : '发送验证码',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                )),
              ]),
              const SizedBox(height: 16),
              _inputLabel('验证码', isDark),
              const SizedBox(height: 4),
              TextField(controller: _emailCodeCtrl,
                decoration: InputDecoration(hintText: '请输入验证码',
                  filled: true, fillColor: isDark ? AppColors.gray700 : AppColors.gray100,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
                style: TextStyle(fontSize: 14, color: isDark ? Colors.white : AppColors.gray900)),
              if (_emailMsg != null) ...[
                const SizedBox(height: 12),
                Text(_emailMsg!, style: TextStyle(fontSize: 14,
                  color: _emailSuccess ? AppColors.success : AppColors.error)),
              ],
              const SizedBox(height: 16),
              SizedBox(height: 44, child: ElevatedButton(
                onPressed: _bindingEmail ? null : _bindEmail,
                style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.primary, foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: Text(_bindingEmail ? '绑定中...' : '绑定邮箱'),
              )),
            ])),
          ]),
          const SizedBox(height: 24),
        ],

        // Notification settings
        _buildCard(isDark, children: [
          Text('通知设置', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : AppColors.gray900)),
          const SizedBox(height: 16),
          _buildToggle(
            title: '到期提醒',
            description: '在订阅到期前收到通知',
            value: (user?.remindExpire ?? 0) == 1,
            isDark: isDark,
            onChanged: (v) => _toggleNotification('remind_expire', v),
          ),
          const SizedBox(height: 16),
          _buildToggle(
            title: '流量提醒',
            description: '在流量使用较高时收到通知',
            value: (user?.remindTraffic ?? 0) == 1,
            isDark: isDark,
            onChanged: (v) => _toggleNotification('remind_traffic', v),
          ),
        ]),
        const SizedBox(height: 24),

        // Active sessions
        _buildCard(isDark, children: [
          Text('活跃会话', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : AppColors.gray900)),
          const SizedBox(height: 16),
          if (_loadingSessions)
            Center(child: SizedBox(width: 24, height: 24,
              child: CircularProgressIndicator(strokeWidth: 2, color: Theme.of(context).colorScheme.primary)))
          else if (_sessions.isEmpty)
            Text('暂无活跃会话', style: TextStyle(fontSize: 14, color: isDark ? AppColors.gray400 : AppColors.gray500))
          else ..._sessions.map((s) {
            final session = s as Map<String, dynamic>;
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? AppColors.gray700.withValues(alpha: 0.5) : AppColors.gray50,
                borderRadius: BorderRadius.circular(12)),
              child: Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(session['ip'] ?? '未知IP', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white : AppColors.gray900)),
                  const SizedBox(height: 2),
                  Text(session['ua'] ?? '未知设备', style: TextStyle(fontSize: 12,
                    color: isDark ? AppColors.gray400 : AppColors.gray500), maxLines: 1, overflow: TextOverflow.ellipsis),
                ])),
                GestureDetector(
                  onTap: () => _removeSession(session['id']?.toString() ?? ''),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(8)),
                    child: Text('移除', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.error)),
                  ),
                ),
              ]),
            );
          }),
        ]),
      ]),
    );
  }

  Widget _buildCard(bool isDark, {required List<Widget> children}) {
    return Container(
      width: double.infinity, padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? AppColors.gray800 : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: isDark ? null : [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }

  Widget _inputLabel(String text, bool isDark) {
    return Text(text, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500,
      color: isDark ? AppColors.gray300 : AppColors.gray700));
  }

  Widget _passwordField(TextEditingController ctrl, bool isDark) {
    return TextField(controller: ctrl, obscureText: true,
      decoration: InputDecoration(
        filled: true, fillColor: isDark ? AppColors.gray700 : AppColors.gray100,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
      style: TextStyle(fontSize: 14, color: isDark ? Colors.white : AppColors.gray900));
  }

  Widget _buildToggle({
    required String title, required String description,
    required bool value, required bool isDark, required ValueChanged<bool> onChanged,
  }) {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500,
          color: isDark ? Colors.white : AppColors.gray900)),
        const SizedBox(height: 2),
        Text(description, style: TextStyle(fontSize: 12, color: isDark ? AppColors.gray400 : AppColors.gray500)),
      ]),
      GestureDetector(
        onTap: () => onChanged(!value),
        child: Container(
          width: 44, height: 24,
          decoration: BoxDecoration(
            color: value ? Theme.of(context).colorScheme.primary : (isDark ? AppColors.gray600 : AppColors.gray300),
            borderRadius: BorderRadius.circular(12)),
          child: AnimatedAlign(
            duration: const Duration(milliseconds: 200),
            alignment: value ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(width: 20, height: 20, margin: const EdgeInsets.all(2),
              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
          ),
        ),
      ),
    ]);
  }
}
