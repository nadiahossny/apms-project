import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/tokens.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
// import '../services/token_store.dart';
import '../widgets/shared_widgets.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ████  LOGIN SCREEN  ████
// ─────────────────────────────────────────────────────────────────────────────
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginState();
}

class _LoginState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _passFocus = FocusNode();
  UserRole _role = UserRole.manager;
  bool _obscure = true, _loading = false, _remember = true;
  String? _error;
  String _gatewayHost = ApiService.gatewayHost;

  late final AnimationController _aC;
  late final Animation<Offset> _slide;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _aC = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _aC, curve: Curves.easeOutCubic));
    _fade = Tween(begin: 0.0, end: 1.0).animate(_aC);
    _aC.forward();
    _gatewayHost = ApiService.gatewayHost;
    // pre-fill manager credentials
    _emailCtrl.text = 'manager@pharma.eg';
    _passCtrl.text = 'PharmaSys@2024';
  }

  void _prefill(UserRole r) {
    setState(() {
      _role = r;
      _error = null;
    });
    if (r == UserRole.manager) {
      _emailCtrl.text = 'manager@pharma.eg';
      _passCtrl.text = 'PharmaSys@2024';
    } else {
      _emailCtrl.text = 'staff@pharma.eg';
      _passCtrl.text = 'Staff@2024';
    }
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false) || _loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final user = await AuthService.login(
        email: _emailCtrl.text,
        password: _passCtrl.text,
        role: _role,
      );
      await Session.save(user);
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/dashboard');
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Network error — check LAN gateway at $_gatewayHost:3000.';
        _loading = false;
      });
    }
  }

  // Future<void> _saveGatewayHost(String host) async {
  //   final trimmed = host.trim();
  //   if (trimmed.isEmpty) return;
  //   ApiService.setGatewayHost(trimmed);
  //   await TokenStore.saveGatewayHost(trimmed);
  //   if (!mounted) return;
  //   setState(() => _gatewayHost = trimmed);
  //   ScaffoldMessenger.of(
  //     context,
  //   ).showSnackBar(SnackBar(content: Text('Gateway host saved: $trimmed')));
  // }

  // Future<void> _testGatewayConnection() async {
  //   try {
  //     final result = await ApiService.testGatewayConnection();
  //     if (!mounted) return;
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(content: Text(result), backgroundColor: Colors.green),
  //     );
  //   } catch (e) {
  //     if (!mounted) return;
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(
  //         content: Text('Gateway test failed: $e'),
  //         backgroundColor: Colors.red,
  //       ),
  //     );
  //   }
  // }

  // Future<void> _showGatewayDialog() async {
  //   final controller = TextEditingController(text: _gatewayHost);
  //   await showDialog<void>(
  //     context: context,
  //     builder: (context) {
  //       return AlertDialog(
  //         title: const Text('Gateway host settings'),
  //         content: Column(
  //           mainAxisSize: MainAxisSize.min,
  //           children: [
  //             TextField(
  //               controller: controller,
  //               decoration: const InputDecoration(
  //                 labelText: 'Gateway IP or hostname',
  //                 hintText: 'e.g. 127.0.0.1 or 192.168.1.10',
  //               ),
  //               keyboardType: TextInputType.url,
  //             ),
  //             const SizedBox(height: 8),
  //             const Text(
  //               'Enter the IP address of the backend server on your local network.\n'
  //               'If the backend is running on this same PC, use 127.0.0.1.\n'
  //               'For Android emulator use 10.0.2.2.',
  //               style: TextStyle(fontSize: 12, color: AC.ink400),
  //             ),
  //             const SizedBox(height: 12),
  //             Text(
  //               'Current host: $_gatewayHost:3000',
  //               style: TextStyle(fontSize: 12, color: AC.ink400),
  //             ),
  //           ],
  //         ),
  //         actions: [
  //           TextButton(
  //             onPressed: () => Navigator.of(context).pop(),
  //             child: const Text('Cancel'),
  //           ),
  //           TextButton(
  //             onPressed: () async {
  //               final host = controller.text.trim();
  //               if (host.isEmpty) return;
  //               await _saveGatewayHost(host);
  //               if (!mounted) return;
  //               Navigator.of(context).pop();
  //             },
  //             child: const Text('Save'),
  //           ),
  //           TextButton(
  //             onPressed: () async {
  //               final host = controller.text.trim();
  //               if (host.isNotEmpty) {
  //                 ApiService.setGatewayHost(host);
  //                 setState(() => _gatewayHost = host);
  //               }
  //               await _testGatewayConnection();
  //             },
  //             child: const Text('Test'),
  //           ),
  //         ],
  //       );
  //     },
  //   );
  // }

  @override
  void dispose() {
    _aC.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _passFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width >= 800;
    return Scaffold(
      backgroundColor: AC.page,
      body: FadeTransition(
        opacity: _fade,
        child: SlideTransition(
          position: _slide,
          child: wide ? _desktop() : _mobile(),
        ),
      ),
    );
  }

  Widget _desktop() => Row(
    children: [
      // Left blue brand panel
      SizedBox(
        width: 380,
        child: Container(
          color: AC.blue500,
          child: Stack(
            children: [
              CustomPaint(painter: BgPainter(), child: const SizedBox.expand()),
              Padding(
                padding: const EdgeInsets.all(48),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: const BoxDecoration(
                            color: AC.white,
                            borderRadius: AR.r10,
                          ),
                          child: const Icon(
                            Icons.local_pharmacy_rounded,
                            color: AC.blue500,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'PharmaSys',
                          style: TextStyle(
                            color: AC.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    const Text(
                      'Pharmacy\nmanagement,\nreinvented.',
                      style: TextStyle(
                        color: AC.white,
                        fontSize: 36,
                        fontWeight: FontWeight.w800,
                        height: 1.15,
                        letterSpacing: -1.0,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Robotic dispensing · AI insights\nFatoora scanning · Real-time stock',
                      style: TextStyle(
                        color: AC.white.withOpacity(0.65),
                        fontSize: 14,
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 32),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _chip(
                          Icons.precision_manufacturing_rounded,
                          'Robot arm',
                        ),
                        _chip(Icons.smart_toy_rounded, 'AI chatbot'),
                        _chip(Icons.document_scanner_rounded, 'Fatoora OCR'),
                        _chip(Icons.security_rounded, 'On-premise'),
                      ],
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: AC.white.withOpacity(0.1),
                        borderRadius: AR.r10,
                        border: Border.all(
                          color: AC.white.withOpacity(0.15),
                          width: 0.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AC.greenFg,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'System online · LAN · Robot idle',
                            style: TextStyle(
                              color: AC.white.withOpacity(0.7),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      // Right form
      Expanded(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(48),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: _form(),
            ),
          ),
        ),
      ),
    ],
  );

  Widget _mobile() => SingleChildScrollView(
    child: Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(24, 56, 24, 32),
          color: AC.blue500,
          child: Column(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: const BoxDecoration(
                  color: AC.white,
                  borderRadius: AR.r12,
                ),
                child: const Icon(
                  Icons.local_pharmacy_rounded,
                  color: AC.blue500,
                  size: 30,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'PharmaSys',
                style: TextStyle(
                  color: AC.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        Padding(padding: const EdgeInsets.all(24), child: _form()),
      ],
    ),
  );

  Widget _chip(IconData icon, String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: AC.white.withOpacity(0.12),
      borderRadius: AR.pill,
      border: Border.all(color: AC.white.withOpacity(0.2), width: 0.5),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: AC.white, size: 13),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(
            color: AC.white,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    ),
  );

  Widget _form() => Form(
    key: _formKey,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Welcome back',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: AC.ink900,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Sign in to your pharmacy dashboard',
          style: TextStyle(fontSize: 13, color: AC.ink400),
        ),
        const SizedBox(height: 28),
        // Role cards
        const Text(
          'SELECT ROLE',
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            color: AC.ink300,
            letterSpacing: 1.4,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _RoleCard(
                role: UserRole.manager,
                selected: _role == UserRole.manager,
                onTap: () => _prefill(UserRole.manager),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _RoleCard(
                role: UserRole.staff,
                selected: _role == UserRole.staff,
                onTap: () => _prefill(UserRole.staff),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        // Email
        const Text(
          'Email address',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AC.ink600,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: _emailCtrl,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          onFieldSubmitted: (_) =>
              FocusScope.of(context).requestFocus(_passFocus),
          style: const TextStyle(fontSize: 13, color: AC.ink900),
          decoration: const InputDecoration(
            hintText: 'manager@pharma.eg',
            prefixIcon: Icon(Icons.email_outlined, size: 17, color: AC.ink300),
          ),
          validator: (v) => (v?.isEmpty ?? true) ? 'Email required' : null,
        ),
        const SizedBox(height: 16),
        // Password
        const Text(
          'Password',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AC.ink600,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: _passCtrl,
          focusNode: _passFocus,
          obscureText: _obscure,
          textInputAction: TextInputAction.done,
          onFieldSubmitted: (_) => _submit(),
          style: const TextStyle(fontSize: 13, color: AC.ink900),
          decoration: InputDecoration(
            hintText: 'Enter your password',
            prefixIcon: const Icon(
              Icons.lock_outline_rounded,
              size: 17,
              color: AC.ink300,
            ),
            suffixIcon: GestureDetector(
              onTap: () => setState(() => _obscure = !_obscure),
              child: Icon(
                _obscure
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                size: 17,
                color: AC.ink300,
              ),
            ),
          ),
          validator: (v) => (v?.isEmpty ?? true) ? 'Password required' : null,
        ),
        const SizedBox(height: 14),
        // Remember device
        GestureDetector(
          onTap: () => setState(() => _remember = !_remember),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: _remember ? AC.blue500 : AC.white,
                  borderRadius: AR.r8,
                  border: Border.all(
                    color: _remember ? AC.blue500 : AC.borderMd,
                    width: 1.5,
                  ),
                ),
                child: _remember
                    ? const Icon(Icons.check_rounded, size: 12, color: AC.white)
                    : null,
              ),
              const SizedBox(width: 7),
              const Text(
                'Remember this device',
                style: TextStyle(fontSize: 12, color: AC.ink400),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        // Error
        if (_error != null)
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: AC.redBg,
              borderRadius: AR.r10,
              border: Border.all(color: AC.redRing, width: 0.5),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  color: AC.redFg,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _error!,
                    style: const TextStyle(fontSize: 12, color: AC.redFg),
                  ),
                ),
              ],
            ),
          ),
        // const SizedBox(height: 12),
        // Row(
        //   children: [
        //     Expanded(
        //       child: Text(
        //         'Gateway host: $_gatewayHost:3000',
        //         style: const TextStyle(fontSize: 12, color: AC.ink900),
        //       ),
        //     ),
        //     TextButton(
        //       onPressed: _showGatewayDialog,
        //       child: const Text('Change'),
        //     ),
        //   ],
        // ),
        // const SizedBox(height: 4),
        // Text(
        //   'Enter the backend server IP here: 127.0.0.1 if it runs on this PC,\n'
        //   '10.0.2.2 for Android emulator, or your LAN host like 192.168.x.x.',
        //   style: TextStyle(fontSize: 11, color: AC.ink400),
        // ),
        const SizedBox(height: 6),
        // Submit
        SizedBox(
          width: double.infinity,
          height: 48,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: AR.r10,
              boxShadow: _loading ? null : AS.button,
            ),
            child: ElevatedButton(
              onPressed: _loading ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AC.blue500,
                foregroundColor: AC.white,
                shape: const RoundedRectangleBorder(borderRadius: AR.r10),
                elevation: 0,
              ),
              child: _loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: AC.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.login_rounded, size: 18),
                        SizedBox(width: 8),
                        Text(
                          'Sign in to dashboard',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: AC.page,
              borderRadius: AR.pill,
              border: Border.all(color: AC.border, width: 0.5),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.shield_outlined, size: 13, color: AC.ink300),
                SizedBox(width: 5),
                Text(
                  'On-premise · LAN only · No cloud transfer',
                  style: TextStyle(fontSize: 10, color: AC.ink300),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

class _RoleCard extends StatelessWidget {
  final UserRole role;
  final bool selected;
  final VoidCallback onTap;
  const _RoleCard({
    required this.role,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isMgr = role == UserRole.manager;
    final fg = AC.blue500; // Both roles use dark blue for consistency
    final bg = AC.blueLt;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? bg : AC.white,
          borderRadius: AR.r10,
          border: Border.all(
            color: selected ? fg.withOpacity(0.5) : AC.border,
            width: selected ? 1.5 : 0.5,
          ),
          boxShadow: selected ? AS.card : null,
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: selected ? fg.withOpacity(0.12) : AC.page,
                borderRadius: AR.r8,
              ),
              child: Icon(
                isMgr ? Icons.manage_accounts_rounded : Icons.badge_outlined,
                color: selected ? fg : AC.ink300,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isMgr ? 'Manager' : 'Staff',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: selected ? fg : AC.ink600,
                    ),
                  ),
                  Text(
                    isMgr ? 'Full access' : 'Scan only',
                    style: const TextStyle(fontSize: 10, color: AC.ink300),
                  ),
                ],
              ),
            ),
            if (selected) Icon(Icons.check_circle_rounded, color: fg, size: 16),
          ],
        ),
      ),
    );
  }
}
