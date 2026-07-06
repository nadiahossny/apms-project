import 'package:flutter/material.dart';
import '../theme/tokens.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/token_store.dart';
import '../widgets/shared_widgets.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ████  SETTINGS SCREEN  ████
// ─────────────────────────────────────────────────────────────────────────────
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsState();
}

class _SettingsState extends State<SettingsScreen> {
  // bool _notifications = true;
  // bool _robotAutoRetry = true;
  // bool _darkMode = false;
  // bool _aiCache = true;
  // int _cacheMinutes = 10;
  // int _rateLimitMgr = 20;
  String _lanIp = ApiService.gatewayHost;

  @override
  void initState() {
    super.initState();
    _lanIp = ApiService.gatewayHost;
  }

  Future<void> _saveSettings() async {
    final host = _lanIp.trim();
    if (host.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid LAN gateway IP.')),
      );
      return;
    }

    ApiService.setGatewayHost(host);
    await TokenStore.saveGatewayHost(host);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Settings saved successfully.'),
        backgroundColor: AC.greenFg,
      ),
    );
  }

  // FIX: Full dialog to securely create a new user profile via the backend
  void _showAddUserDialog() {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    String role = 'staff';
    bool loading = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AC.white,
          title: const Text('Add New User', style: TextStyle(fontSize: 16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Full Name', filled: true, fillColor: AC.page, border: InputBorder.none),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: emailCtrl,
                decoration: const InputDecoration(labelText: 'Email Address', filled: true, fillColor: AC.page, border: InputBorder.none),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: passCtrl,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Password', filled: true, fillColor: AC.page, border: InputBorder.none),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: role,
                decoration: const InputDecoration(filled: true, fillColor: AC.page, border: InputBorder.none),
                items: const [
                  DropdownMenuItem(value: 'staff', child: Text('Staff')),
                  DropdownMenuItem(value: 'manager', child: Text('Manager')),
                ],
                onChanged: (v) => setDialogState(() => role = v!),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: loading ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: AC.ink400)),
            ),
            appBtn(
              'Create User',
              onTap: loading ? null : () async {
                if (nameCtrl.text.isEmpty || emailCtrl.text.isEmpty || passCtrl.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('All fields are required')));
                  return;
                }
                setDialogState(() => loading = true);
                try {
                  await ApiService.auth.register(
                    fullName: nameCtrl.text,
                    email: emailCtrl.text,
                    password: passCtrl.text,
                    role: role,
                  );
                  if (mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User created successfully!'), backgroundColor: AC.greenFg));
                  }
                } catch (e) {
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AC.redFg));
                  setDialogState(() => loading = false);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ScreenTopbar(
          title: 'Settings',
          subtitle: 'Manage your account ',
          actions: [
            appBtn('Save settings', icon: Icons.save_rounded, onTap: _saveSettings),
          ],
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (AuthService.isManager) ...[
                  _section('User Management'),
                  const SizedBox(height: 12),
                  appCard(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Team Access', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AC.ink900)),
                                SizedBox(height: 4),
                                Text('Add new staff or manager profiles to the APMS system.', style: TextStyle(fontSize: 12, color: AC.ink400)),
                              ],
                            ),
                          ),
                          appBtn('Add User', icon: Icons.person_add_rounded, onTap: _showAddUserDialog),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
                _section('Local Gateway (Required)'),
                const SizedBox(height: 12),
                appCard(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Backend LAN IP Address',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AC.ink900),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'The IP address of the local PC running the Node.js backend. '
                          'Usually 192.168.x.x on Wi-Fi, 127.0.0.1 for local desktop, or 10.0.2.2 for Android emulator.',
                          style: TextStyle(fontSize: 12, color: AC.ink400),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                initialValue: _lanIp,
                                onChanged: (v) => _lanIp = v,
                                decoration: const InputDecoration(
                                  hintText: 'e.g., 192.168.1.10',
                                  prefixIcon: Icon(Icons.router_rounded, size: 16, color: AC.ink400),
                                  border: OutlineInputBorder(borderRadius: AR.r8, borderSide: BorderSide.none),
                                  filled: true, fillColor: AC.page,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            appBtn(
                              'Test Connection',
                              icon: Icons.wifi_find_rounded,
                              bg: AC.blue500,
                              onTap: () async {
                                final host = _lanIp.trim();
                                if (host.isNotEmpty) ApiService.setGatewayHost(host);
                                try {
                                  final msg = await ApiService.testGatewayConnection();
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: AC.greenFg));
                                } catch (e) {
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AC.redFg));
                                }
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                 const SizedBox(height: 40),
                Center(
                  child: TextButton.icon(
                    onPressed: () async {
                      await ApiService.auth.logout();
                      if (!mounted) return;
                      Navigator.of(context).pushReplacementNamed('/login');
                    },
                    icon: const Icon(Icons.logout_rounded, size: 16),
                    label: const Text('Sign out of account', style: TextStyle(fontWeight: FontWeight.w600)),
                    style: TextButton.styleFrom(foregroundColor: AC.redFg, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
                  ),
                ),
                // _section('Preferences'),
                // const SizedBox(height: 12),
                // appCard(
                //   child: Column(
                //     children: [
                      
                //       // _toggle('Push notifications', 'Alert me on low stock and expiring items', _notifications, (v) => setState(() => _notifications = v)),
                //       appDivider(),

                //       // _toggle('Dark mode', 'System UI theme (coming soon)', _darkMode, (v) => setState(() => _darkMode = v)),
                //     ],
                //   ),
                // )
              ],
            ),
          ))
          ])
          ;}
                // const SizedBox(height: 32),
    //             _section('Hardware & AI'),
    //             const SizedBox(height: 12),
    //             appCard(
    //               child: Column(
    //                 children: [
    //                   _toggle('Robot auto-retry', 'Automatically retry failed picks 1 time before halting', _robotAutoRetry, (v) => setState(() => _robotAutoRetry = v)),
    //                   appDivider(),
    //                   _toggle('AI semantic cache', 'Use local DB cache for duplicate queries', _aiCache, (v) => setState(() => _aiCache = v)),
    //                   appDivider(),
    //                   Padding(
    //                     padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    //                     child: Row(
    //                       mainAxisAlignment: MainAxisAlignment.spaceBetween,
    //                       children: [
    //                         const Column(
    //                           crossAxisAlignment: CrossAxisAlignment.start,
    //                           children: [
    //                             Text('Cache TTL', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AC.ink900)),
    //                             SizedBox(height: 2),
    //                             Text('Time to live for cached AI reports', style: TextStyle(fontSize: 12, color: AC.ink400)),
    //                           ],
    //                         ),
    //                         _stepper(_cacheMinutes, (v) => setState(() => _cacheMinutes = v), 'min', 1, 60),
    //                       ],
    //                     ),
    //                   ),
    //                   appDivider(),
    //                   Padding(
    //                     padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    //                     child: Row(
    //                       mainAxisAlignment: MainAxisAlignment.spaceBetween,
    //                       children: [
    //                         const Column(
    //                           crossAxisAlignment: CrossAxisAlignment.start,
    //                           children: [
    //                             Text('Manager rate limit', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AC.ink900)),
    //                             SizedBox(height: 2),
    //                             Text('AI queries per minute', style: TextStyle(fontSize: 12, color: AC.ink400)),
    //                           ],
    //                         ),
    //                         _stepper(_rateLimitMgr, (v) => setState(() => _rateLimitMgr = v), 'req', 5, 100),
    //                       ],
    //                     ),
    //                   ),
    //                 ],
    //               ),
    //             ),
    //            
    //           ],
    //         ),
    //       ),
    //     ),
    //   ],
    // );
  // }

  Widget _section(String title) => Text(
    title,
    style: const TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w700,
      color: AC.ink400,
      letterSpacing: 0.5,
    ),
  );

  // Widget _toggle(String t, String s, bool val, ValueChanged<bool> onChanged) =>
  //     InkWell(
  //       onTap: () => onChanged(!val),
  //       child: Padding(
  //         padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
  //         child: Row(
  //           children: [
  //             Expanded(
  //               child: Column(
  //                 crossAxisAlignment: CrossAxisAlignment.start,
  //                 children: [
  //                   Text(t, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AC.ink900)),
  //                   const SizedBox(height: 2),
  //                   Text(s, style: const TextStyle(fontSize: 12, color: AC.ink400)),
  //                 ],
  //               ),
  //             ),
  //             Switch(
  //               value: val,
  //               onChanged: onChanged,
  //               activeColor: AC.blue500,
  //               activeTrackColor: AC.blueLt,
  //               inactiveThumbColor: AC.ink300,
  //               inactiveTrackColor: AC.page,
  //             ),
  //           ],
  //         ),
  //       ),
  //     );

  // Widget _stepper(int val, ValueChanged<int> onChanged, String unit, int min, int max) => Row(
  //   mainAxisSize: MainAxisSize.min,
  //   children: [
  //     InkWell(
  //       onTap: val > min ? () => onChanged(val - 1) : null,
  //       borderRadius: AR.r8,
  //       child: Container(
  //         width: 28, height: 28,
  //         decoration: BoxDecoration(color: AC.page, borderRadius: AR.r8, border: Border.all(color: AC.border, width: 0.5)),
  //         child: const Icon(Icons.remove_rounded, size: 14, color: AC.ink400),
  //       ),
  //     ),
  //     Padding(
  //       padding: const EdgeInsets.symmetric(horizontal: 12),
  //       child: Text('$val $unit', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AC.ink900)),
  //     ),
  //     InkWell(
  //       onTap: val < max ? () => onChanged(val + 1) : null,
  //       borderRadius: AR.r8,
  //       child: Container(
  //         width: 28, height: 28,
  //         decoration: BoxDecoration(color: AC.page, borderRadius: AR.r8, border: Border.all(color: AC.border, width: 0.5)),
  //         child: const Icon(Icons.add_rounded, size: 14, color: AC.ink400),
  //       ),
  //     ),
  //   ],
  // );


}