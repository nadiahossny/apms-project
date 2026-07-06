import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/tokens.dart';
import '../services/api_service.dart';
import '../widgets/shared_widgets.dart';

class RobotPanelScreen extends StatefulWidget {
  const RobotPanelScreen({super.key});
  @override
  State<RobotPanelScreen> createState() => _RobotState();
}

class _RobotState extends State<RobotPanelScreen> {
  RobotJobDto? _selJob;
  bool _running = false;
  String _armStatus = 'Idle / Ready';
  final _activityLog = <_LogLine>[];

  List<RobotJobDto> _jobs = [];
  bool _isLoading = true;
  String? _errorMsg;

  RobotWebSocket? _ws;

  @override
  void initState() {
    super.initState();
    _loadJobs();
    _connectWebSocket();
  }

  Future<void> _loadJobs({bool autoSelect = true}) async {
    setState(() {
      _isLoading = true;
      _errorMsg = null;
    });
    try {
      final jobs = await ApiService.robot.getJobs(limit: 50);
      if (!mounted) return;
      setState(() {
        _jobs = jobs;
        if (autoSelect && _jobs.isNotEmpty && _selJob == null) {
          _selJob = _jobs.first;
          _running = _selJob!.status == 'DISPATCHED';
        } else if (_selJob != null) {
          try {
            _selJob = _jobs.firstWhere((job) => job.jobId == _selJob!.jobId);
            _running = _selJob!.status == 'DISPATCHED';
          } catch (_) {
            _selJob = null;
          }
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMsg = 'Failed to load jobs: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _connectWebSocket() {
    _ws = RobotWebSocket(
      onEvent: _handleWsEvent,
      onError: (e) => _addLog('ERROR', 'System error: $e'),
      onDone: () => _addLog('SYS', 'System reconnecting...'),
    );
    _ws!.connect();
  }

  void _handleWsEvent(Map<String, dynamic> event) {
    if (!mounted) return;
    if (event['type'] == 'ROBOT_ACK') {
      final jobId = event['jobId'];
      final status = event['status'];
      final msg = event['message'];

      setState(() {
        _addLog('SYS', 'Job $jobId: $msg');
        _armStatus = (status == 'COMPLETED' || status == 'ABORTED' || status == 'IDLE') ? 'Idle / Ready' : 'Moving...';
        _loadJobs(autoSelect: false);
      });
    }
  }

  void _addLog(String type, String text) {
    final now = DateTime.now();
    final timeStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
    _activityLog.insert(0, _LogLine(timeStr, type, text));
    if (_activityLog.length > 50) _activityLog.removeLast(); 
  }

  Future<void> _abortJob() async {
    if (_selJob == null) return;
    try {
      await ApiService.robot.abort(_selJob!.jobId);
      _addLog('SYS', 'Abort signal sent for ${_selJob!.jobId}');
    } catch (e) {
      _addLog('ERROR', 'Failed to cancel: $e');
    }
  }

  @override
  void dispose() {
    _ws?.disconnect();
    super.dispose();
  }

  Future<void> _dispatch() async {
    if (_selJob == null || _running) return;
    if (_selJob!.jobId.isEmpty || _selJob!.jobId == 'null') {
      _addLog('ERROR', 'Invalid queue item');
      return;
    }

    setState(() {
      _running = true;
      _armStatus = 'Starting...';
    });

    _addLog('SYS', 'Retrying job ${_selJob!.jobId}');
    try {
      await ApiService.robot.retryJob(_selJob!.jobId);
      _loadJobs(autoSelect: false);
    } catch (e) {
      _addLog('ERROR', 'Failed to start: $e');
      setState(() {
        _armStatus = 'Idle / Ready';
        _running = false;
      });
    }
  }

  Future<void> _deleteJob() async {
  if (_selJob == null) return;
  try {
    await ApiService.robot.deleteJob(_selJob!.jobId);
    _addLog('SYS', 'Deleted job ${_selJob!.jobId} from history');
    setState(() => _selJob = null);
    _loadJobs();
  } catch (e) {
    _addLog('ERROR', 'Failed to delete job: $e');
  }
}

  void _reset() async {
    _addLog('SYS', 'Flushing active queues...');
    for (final job in _jobs) {
      if (job.status == 'DISPATCHED') {
        try { await ApiService.robot.abort(job.jobId); } catch (_) {}
      }
    }
    setState(() {
      _running = false;
      _armStatus = 'Idle / Ready';
      _selJob = null;
      _activityLog.clear();
    });
    _loadJobs(autoSelect: false);
  }

  @override
  Widget build(BuildContext context) {
    final completedCount = _jobs.where((j) => j.status == 'COMPLETED').length;
    final failedCount = _jobs.where((j) => j.status == 'ABORTED' || j.status == 'FAILED').length;

    return Column(
      children: [
        ScreenTopbar(
          title: 'Robot Control',
          subtitle: 'Manage the automated dispensing arm',
          actions: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(color: const Color(0xFFF3F6FA), borderRadius: AR.r8, border: Border.all(color: AC.border, width: 0.5)),
              child: const Row(
                children: [
                  Icon(Icons.link_rounded, size: 14, color: AC.ink400),
                  SizedBox(width: 6),
                  Text('Connection: Secured', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AC.ink600)),
                ],
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            children: [
              _statCard('Total Jobs', '${_jobs.length}', AC.blue500, AC.blueLt),
              const SizedBox(width: 12),
              _statCard('Completed', '$completedCount', AC.greenFg, AC.greenBg),
              const SizedBox(width: 12),
              _statCard('Canceled / Failed', '$failedCount', AC.redFg, AC.redBg),
              const SizedBox(width: 12),
              _statCard('Arm Status', _armStatus, _armStatus.contains('Idle') ? AC.greenFg : AC.amberFg, _armStatus.contains('Idle') ? AC.greenBg : AC.amberBg),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _errorMsg != null
              ? Center(child: Text(_errorMsg!, style: const TextStyle(color: AC.redFg)))
              : LayoutBuilder(
                  builder: (ctx, cst) {
                    final isWide = cst.maxWidth >= 700;

                    final queueCardUI = appCard(
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(14),
                            child: Row(
  children: [
    const Expanded(child: Text('Dispensing Queue', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AC.ink900))),
    if (_running)
      appBtn('Stop Arm', icon: Icons.stop_circle_rounded, bg: AC.redBg, onTap: _abortJob),
    if (!_running && _selJob != null) ...[
      appBtn('Delete Job', icon: Icons.delete_outline_rounded, bg: AC.redBg, fg: AC.redFg, onTap: _deleteJob),
      const SizedBox(width: 8),
      appBtn('Process Selection', icon: Icons.play_arrow_rounded, onTap: _dispatch),
    ],
    const SizedBox(width: 8),
    appBtn('Clear Errors', icon: Icons.refresh_rounded, bg: AC.page, fg: AC.ink900, onTap: _reset),
  ],
),
                          ),
                          appDivider(),
                          SizedBox(
                            height: 48,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              itemCount: _jobs.length,
                              itemBuilder: (_, i) {
                                final sel = _selJob != null && _jobs[i].jobId == _selJob!.jobId;
                                return InkWell(
                                  onTap: _running ? null : () => setState(() => _selJob = _jobs[i]),
                                  borderRadius: AR.r8,
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 150),
                                    margin: const EdgeInsets.only(right: 8),
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                    decoration: BoxDecoration(color: sel ? AC.blueLt : AC.page, borderRadius: AR.r8, border: Border.all(color: sel ? AC.blue500 : AC.border, width: 0.5)),
                                    child: Text('Order ${_jobs[i].jobId.split('-').last}', style: TextStyle(fontSize: 12, fontWeight: sel ? FontWeight.w600 : FontWeight.w500, color: sel ? AC.blue500 : AC.ink600)),
                                  ),
                                );
                              },
                            ),
                          ),
                          appDivider(),
                          Expanded(
                            child: _selJob == null
                                ? const Center(child: Text('Select an order from the list above', style: TextStyle(fontSize: 13, color: AC.ink300)))
                                : ListView.builder(
                                    padding: const EdgeInsets.all(16),
                                    itemCount: _selJob!.pickSequence.length,
                                    itemBuilder: (_, i) {
                                      final item = _selJob!.pickSequence[i];
                                      final status = item['status'] as String? ?? 'PENDING';
                                      final isDone = status == 'DONE';
                                      final isFailed = status == 'FAILED';
                                      final isSending = status == 'SENDING';

                                      Color fg = isDone ? AC.greenFg : isFailed ? AC.redFg : isSending ? AC.blue500 : AC.ink400;
                                      Color bg = isDone ? AC.greenBg : isFailed ? AC.redBg : isSending ? AC.blueLt : AC.page;
                                      String lbl = isDone ? 'Dispensed' : isFailed ? 'Failed' : isSending ? 'Moving...' : 'Waiting';
                                      
                                      return AnimatedContainer(
                                        duration: const Duration(milliseconds: 200),
                                        margin: const EdgeInsets.only(bottom: 10),
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(color: bg, borderRadius: AR.r10, border: Border.all(color: fg.withAlpha((0.3 * 255).toInt()), width: 0.5)),
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 32, height: 32,
                                              decoration: BoxDecoration(color: fg.withAlpha((0.15 * 255).toInt()), borderRadius: AR.pill),
                                              child: Center(
                                                child: isSending
                                                    ? SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: fg))
                                                    : Icon(isDone ? Icons.check_rounded : isFailed ? Icons.close_rounded : Icons.medication_outlined, size: 16, color: fg),
                                              ),
                                            ),
                                            const SizedBox(width: 14),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(item['medicine_name']?.toString() ?? 'Medicine', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AC.ink900)),
                                                  const SizedBox(height: 2),
                                                  Text('Quantity: ${item['qty']?.toString() ?? '1'}', style: const TextStyle(fontSize: 12, color: AC.ink400)),
                                                ],
                                              ),
                                            ),
                                            Text(item['bin']?.toString() ?? 'Bin', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AC.ink600)),
                                            const SizedBox(width: 14),
                                            appBadge(lbl, fg, fg.withAlpha((0.1 * 255).toInt())),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                          ),
                        ],
                      ),
                    );

                    final sidePanelUI = SizedBox(
                      width: isWide ? 300 : double.infinity,
                      child: appCard(
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AC.border, width: 0.5))),
                              child: Row(
                                children: [
                                  Container(width: 8, height: 8, decoration: const BoxDecoration(color: AC.blue500, shape: BoxShape.circle)),
                                  const SizedBox(width: 10),
                                  const Text('System Activity Log', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AC.ink900)),
                                ],
                              ),
                            ),
                            Expanded(
                              child: ListView.builder(
                                padding: const EdgeInsets.all(12),
                                itemCount: _activityLog.length,
                                itemBuilder: (_, i) {
                                  final l = _activityLog[i];
                                  final color = l.type == 'ERROR' ? AC.redFg : AC.ink600;
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(l.ts, style: const TextStyle(fontSize: 11, color: AC.ink300)),
                                        const SizedBox(width: 10),
                                        Expanded(child: Text(l.text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: color))),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    );

                    return Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: isWide
                          ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: queueCardUI), const SizedBox(width: 12), sidePanelUI])
                          : Column(children: [Expanded(child: queueCardUI), const SizedBox(height: 12), Expanded(child: sidePanelUI)]),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _statCard(String label, String val, Color fg, Color bg) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(12), // Slightly reduced padding for tighter screens
      decoration: BoxDecoration(
        color: AC.white, 
        borderRadius: AR.r12, 
        border: Border.all(color: AC.border, width: 0.5), 
        boxShadow: AS.card
      ),
      child: Row(
        children: [
          Container(
            width: 38, height: 38, // Slightly smaller icon container
            decoration: BoxDecoration(color: bg, shape: BoxShape.circle), 
            child: Icon(Icons.analytics_outlined, color: fg, size: 18)
          ),
          const SizedBox(width: 10),
          // FIX: Wrapped Column in Expanded so it cannot push past the card boundaries
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label, 
                  maxLines: 1, 
                  overflow: TextOverflow.ellipsis, // Truncates with "..." if too long
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AC.ink400)
                ),
                const SizedBox(height: 2),
                // FIX: Shrinks the number text down instead of overflowing if it gets massive
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    val, 
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: fg, letterSpacing: -0.5)
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _LogLine {
  final String ts, type, text;
  const _LogLine(this.ts, this.type, this.text);
}