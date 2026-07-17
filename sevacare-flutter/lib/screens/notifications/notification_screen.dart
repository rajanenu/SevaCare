import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/models.dart';
import '../../providers/app_state.dart';
import '../../widgets/widgets.dart';

class NotificationScreen extends ConsumerStatefulWidget {
  const NotificationScreen({super.key});

  @override
  ConsumerState<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends ConsumerState<NotificationScreen> {
  NotificationCollection? _data;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  String get _recipientType {
    final role = ref.read(authProvider).role;
    return switch (role) {
      UserRole.doctor => 'DOCTOR',
      UserRole.admin => 'ADMIN',
      UserRole.staff => 'STAFF',
      _ => 'PATIENT',
    };
  }

  String get _recipientId {
    final auth = ref.read(authProvider);
    return auth.subjectPublicId ?? '';
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final auth = ref.read(authProvider);
      final repo = ref.read(repositoryProvider);
      final data = await repo.getNotifications(
        auth.tenantPublicId ?? '',
        _recipientId,
        _recipientType,
        auth.token ?? '',
      );
      if (mounted) setState(() => _data = data);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _markAllRead() async {
    try {
      final auth = ref.read(authProvider);
      await ref.read(repositoryProvider).markAllNotificationsRead(
        auth.tenantPublicId ?? '',
        _recipientId,
        _recipientType,
        auth.token ?? '',
      );
      await _load();
    } catch (_) {}
  }

  Future<void> _markRead(String notifId) async {
    try {
      final auth = ref.read(authProvider);
      await ref.read(repositoryProvider).markNotificationRead(
        auth.tenantPublicId ?? '',
        notifId,
        auth.token ?? '',
      );
      await _load();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final hospital = ref.watch(hospitalProvider);
    final auth = ref.watch(authProvider);
    final unread = _data?.unreadCount ?? 0;

    return AppShell(
      hospitalName: hospital.hospitalName,
      role: auth.role,
      showBackButton: true,
      onBack: () => context.pop(),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: PageHeader(
                  title: 'Notifications',
                  subtitle: unread > 0 ? '$unread unread' : 'All caught up',
                ),
              ),
              if (unread > 0)
                GestureDetector(
                  onTap: _markAllRead,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: context.colors.primarySoft,
                      borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                      border: Border.all(color: context.colors.primary.withValues(alpha: 0.25)),
                    ),
                    child: Text('Mark all read', style: AppTextStyles.chipLabel(context.colors.primary)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (_loading)
            const ShimmerList(count: 5, cardHeight: 76)
          else if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: AppErrorState(message: _error!, onRetry: _load),
            )
          else if (_data == null || _data!.notifications.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: AppEmptyState(
                icon: Icons.notifications_none_rounded,
                title: 'No notifications yet',
                message: "You'll be notified about appointments, prescriptions, and admin updates here.",
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _data!.notifications.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (ctx, i) {
                final n = _data!.notifications[i];
                return _NotificationTile(
                  notification: n,
                  onTap: () => _markRead(n.notificationPublicId),
                );
              },
            ),
        ],
      ),
    );
  }
}

// ── Notification tile ─────────────────────────────────────────────────────────

class _NotificationTile extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback onTap;

  const _NotificationTile({required this.notification, required this.onTap});

  static const _typeConfig = <String, (IconData, Color)>{
    'LEAVE_REQUEST':       (Icons.event_busy_outlined,          Color(0xFF5148CC)),
    'LEAVE_APPROVED':      (Icons.check_circle_outline,         Color(0xFF0D9488)),
    'LEAVE_DECLINED':      (Icons.cancel_outlined,              Color(0xFFDC2626)),
    'AUTO_APPROVED':       (Icons.auto_awesome_outlined,        Color(0xFF0D9488)),
    'APPOINTMENT_REMINDER':(Icons.access_time_outlined,         Color(0xFFD97706)),
    'PRESCRIPTION_SHARED': (Icons.medication_outlined,          Color(0xFF2563EB)),
    'ADMIN_MESSAGE':       (Icons.campaign_outlined,            Color(0xFF7C3AED)),
  };

  (IconData, Color) _config(BuildContext context) =>
      _typeConfig[notification.notifType] ?? (Icons.notifications_outlined, context.colors.primary);

  String get _timeAgo {
    try {
      final dt = DateTime.parse(notification.createdAt).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      return '${diff.inDays}d ago';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final (icon, color) = _config(context);
    final isUnread = !notification.read;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        decoration: BoxDecoration(
          color: isUnread ? color.withValues(alpha: 0.06) : context.colors.surface,
          borderRadius: BorderRadius.circular(AppTheme.radius),
          border: Border.all(
            color: isUnread ? color.withValues(alpha: 0.20) : context.colors.border,
            width: isUnread ? 1.5 : 1,
          ),
          boxShadow: isUnread
              ? [BoxShadow(color: color.withValues(alpha: 0.08), blurRadius: 10, offset: const Offset(0, 3))]
              : [],
        ),
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                if (isUnread)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(notification.title,
                            style: AppTextStyles.cardTitle(context.colors.text)
                                .copyWith(fontWeight: isUnread ? FontWeight.w700 : FontWeight.w600)),
                      ),
                      const SizedBox(width: 8),
                      Text(_timeAgo, style: AppTextStyles.label(context.colors.textMuted)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(notification.body,
                      style: AppTextStyles.bodyText(context.colors.textMuted),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
