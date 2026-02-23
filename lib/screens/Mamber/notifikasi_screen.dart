import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/supabase/db_notification.dart';

enum NotificationType { ktaExpired, monthlyFee, competition, general }

enum NotificationFilter { all, unread, kta, monthlyFee, competition, general }

class NotificationItem {
  final String id;
  final String title;
  final String message;
  final DateTime date;
  final NotificationType type;
  final bool isRead;
  final String priority;
  final String? imageUrl;
  final String? actionUrl;
  final Map<String, dynamic>? metadata;

  const NotificationItem({
    required this.id,
    required this.title,
    required this.message,
    required this.date,
    required this.type,
    this.isRead = false,
    this.priority = 'normal',
    this.imageUrl,
    this.actionUrl,
    this.metadata,
  });

  NotificationItem copyWith({
    String? id,
    String? title,
    String? message,
    DateTime? date,
    NotificationType? type,
    bool? isRead,
    String? priority,
    String? imageUrl,
    String? actionUrl,
    Map<String, dynamic>? metadata,
  }) {
    return NotificationItem(
      id: id ?? this.id,
      title: title ?? this.title,
      message: message ?? this.message,
      date: date ?? this.date,
      type: type ?? this.type,
      isRead: isRead ?? this.isRead,
      priority: priority ?? this.priority,
      imageUrl: imageUrl ?? this.imageUrl,
      actionUrl: actionUrl ?? this.actionUrl,
      metadata: metadata ?? this.metadata,
    );
  }
}

class NotifikasiScreen extends StatefulWidget {
  const NotifikasiScreen({super.key});

  @override
  State<NotifikasiScreen> createState() => _NotifikasiScreenState();
}

class _NotifikasiScreenState extends State<NotifikasiScreen> {
  List<NotificationItem> _notifications = [];
  bool _isLoading = false;
  String? _errorMessage;
  NotificationFilter _activeFilter = NotificationFilter.all;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      if (!mounted) return;
      setState(() {
        _notifications = [];
        _isLoading = false;
        _errorMessage = 'Silakan login untuk melihat notifikasi.';
      });
      return;
    }

    try {
      final response = await Supabase.instance.client
          .from('notifications')
          .select(
            'id,type,title,message,user_id,priority,is_read,image_url,action_url,metadata,created_at,read_at',
          )
          .or('user_id.eq.${user.id},user_id.is.null')
          .order('created_at', ascending: false);

      final rows = List<Map<String, dynamic>>.from(response as List);
      final items = rows
          .map((row) => _mapDbNotification(DbNotification.fromJson(row)))
          .toList();

      if (!mounted) return;
      setState(() {
        _notifications = items;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage =
            'Gagal memuat notifikasi. Tarik ke bawah untuk mencoba lagi.';
      });
    }
  }

  List<NotificationItem> get _filteredNotifications {
    switch (_activeFilter) {
      case NotificationFilter.all:
        return _notifications;
      case NotificationFilter.unread:
        return _notifications.where((item) => !item.isRead).toList();
      case NotificationFilter.kta:
        return _notifications
            .where((item) => item.type == NotificationType.ktaExpired)
            .toList();
      case NotificationFilter.monthlyFee:
        return _notifications
            .where((item) => item.type == NotificationType.monthlyFee)
            .toList();
      case NotificationFilter.competition:
        return _notifications
            .where((item) => item.type == NotificationType.competition)
            .toList();
      case NotificationFilter.general:
        return _notifications
            .where((item) => item.type == NotificationType.general)
            .toList();
    }
  }

  int get _unreadCount => _notifications.where((n) => !n.isRead).length;

  int get _todayCount {
    final now = DateTime.now();
    return _notifications
        .where(
          (n) =>
              n.date.year == now.year &&
              n.date.month == now.month &&
              n.date.day == now.day,
        )
        .length;
  }

  Future<void> _markNotificationAsRead(String notificationId) async {
    final index = _notifications.indexWhere(
      (item) => item.id == notificationId,
    );
    if (index < 0 || _notifications[index].isRead) {
      return;
    }

    final updated = _notifications[index].copyWith(isRead: true);
    if (!mounted) return;
    setState(() {
      _notifications[index] = updated;
    });

    try {
      await Supabase.instance.client
          .from('notifications')
          .update({
            'is_read': true,
            'read_at': DateTime.now().toIso8601String(),
          })
          .eq('id', notificationId);
    } catch (_) {
      // Keep optimistic state even if update policy is unavailable for this user.
    }
  }

  Future<void> _markAllAsRead() async {
    final unreadIds = _notifications
        .where((item) => !item.isRead)
        .map((item) => item.id)
        .toList();

    if (unreadIds.isEmpty) {
      return;
    }

    if (!mounted) return;
    setState(() {
      _notifications = _notifications
          .map((item) => item.copyWith(isRead: true))
          .toList();
    });

    try {
      await Supabase.instance.client
          .from('notifications')
          .update({
            'is_read': true,
            'read_at': DateTime.now().toIso8601String(),
          })
          .inFilter('id', unreadIds);
    } catch (_) {
      // Ignore persistence failure to keep UI responsive.
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Semua notifikasi ditandai sudah dibaca'),
        backgroundColor: Color(0xFF0EA5A4),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _removeNotification(String notificationId) {
    final originalIndex = _notifications.indexWhere(
      (item) => item.id == notificationId,
    );
    if (originalIndex < 0) {
      return;
    }

    final removed = _notifications[originalIndex];
    if (!mounted) return;
    setState(() {
      _notifications.removeAt(originalIndex);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Notifikasi dihapus dari daftar'),
        backgroundColor: const Color(0xFF0EA5A4),
        action: SnackBarAction(
          label: 'Undo',
          textColor: Colors.white,
          onPressed: () {
            if (!mounted) return;
            setState(() {
              _notifications.insert(originalIndex, removed);
            });
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final displayed = _filteredNotifications;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF059669),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF10B981), Color(0xFF0EA5A4)],
            ),
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: const Text(
          'Notifikasi',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loadNotifications,
            icon: const Icon(Icons.refresh, color: Colors.white),
          ),
          if (_unreadCount > 0)
            IconButton(
              tooltip: 'Tandai semua dibaca',
              onPressed: _markAllAsRead,
              icon: const Icon(Icons.done_all_rounded, color: Colors.white),
            ),
        ],
      ),
      body: Column(
        children: [
          _buildHeroSummary(),
          _buildFilterRow(),
          Expanded(
            child: RefreshIndicator(
              color: const Color(0xFF0EA5A4),
              onRefresh: _loadNotifications,
              child: _buildContent(displayed),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroSummary() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF10B981), Color(0xFF0D9488)],
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x3310B981),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: -32,
            right: -18,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            bottom: -26,
            left: -12,
            child: Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(11),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.campaign_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Info Klub & Pengumuman',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'KTA, pendaftaran lomba, iuran, dan informasi umum dari admin.',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.4,
                  color: Colors.white.withValues(alpha: 0.88),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _buildHeroStat(
                      label: 'Belum Dibaca',
                      value: _unreadCount.toString(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildHeroStat(
                      label: 'Total',
                      value: _notifications.length.toString(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildHeroStat(
                      label: 'Hari Ini',
                      value: _todayCount.toString(),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeroStat({required String label, required String value}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterRow() {
    final filters = [
      _FilterChipData(NotificationFilter.all, 'Semua', Icons.widgets_rounded),
      _FilterChipData(
        NotificationFilter.unread,
        'Belum Dibaca',
        Icons.mark_email_unread_rounded,
      ),
      _FilterChipData(NotificationFilter.kta, 'KTA', Icons.badge_rounded),
      _FilterChipData(
        NotificationFilter.monthlyFee,
        'Pembayaran',
        Icons.account_balance_wallet_rounded,
      ),
      _FilterChipData(
        NotificationFilter.competition,
        'Lomba',
        Icons.emoji_events_rounded,
      ),
      _FilterChipData(
        NotificationFilter.general,
        'Umum',
        Icons.campaign_rounded,
      ),
    ];

    return SizedBox(
      height: 54,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemBuilder: (context, index) {
          final chip = filters[index];
          final isSelected = _activeFilter == chip.filter;
          return ChoiceChip(
            selected: isSelected,
            onSelected: (_) {
              setState(() {
                _activeFilter = chip.filter;
              });
            },
            label: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(chip.icon, size: 16),
                const SizedBox(width: 6),
                Text(chip.label),
              ],
            ),
            selectedColor: const Color(0xFF0EA5A4),
            backgroundColor: Colors.white,
            side: BorderSide(
              color: isSelected
                  ? const Color(0xFF0EA5A4)
                  : const Color(0xFFE2E8F0),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            labelStyle: TextStyle(
              color: isSelected ? Colors.white : const Color(0xFF334155),
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          );
        },
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemCount: filters.length,
      ),
    );
  }

  Widget _buildContent(List<NotificationItem> displayed) {
    if (_isLoading) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 180),
          Center(child: CircularProgressIndicator(color: Color(0xFF0EA5A4))),
        ],
      );
    }

    if (_errorMessage != null && _notifications.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 80, 24, 24),
        children: [
          const Icon(
            Icons.cloud_off_rounded,
            size: 68,
            color: Color(0xFF94A3B8),
          ),
          const SizedBox(height: 16),
          Text(
            _errorMessage!,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF475569),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: ElevatedButton.icon(
              onPressed: _loadNotifications,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Coba Lagi'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0EA5A4),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      );
    }

    if (displayed.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 80, 24, 24),
        children: [
          Container(
            height: 90,
            width: 90,
            decoration: BoxDecoration(
              color: const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(
              Icons.notifications_paused_rounded,
              size: 44,
              color: Color(0xFF94A3B8),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Tidak ada notifikasi',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Color(0xFF334155),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _emptyMessageByFilter(),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF64748B),
              height: 1.5,
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      itemCount: displayed.length,
      itemBuilder: (context, index) {
        final notification = displayed[index];
        return _buildAnimatedCard(notification, index);
      },
    );
  }

  Widget _buildAnimatedCard(NotificationItem notification, int index) {
    final delay = 220 + (index * 35);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: delay.clamp(220, 640)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 14),
            child: child,
          ),
        );
      },
      child: _buildNotificationCard(notification),
    );
  }

  Widget _buildNotificationCard(NotificationItem notification) {
    final visual = _visualForType(notification.type);

    return Dismissible(
      key: Key(notification.id),
      direction: DismissDirection.horizontal,
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd && notification.isRead) {
          return false;
        }
        return true;
      },
      onDismissed: (direction) {
        if (direction == DismissDirection.startToEnd) {
          _markNotificationAsRead(notification.id);
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Notifikasi ditandai sudah dibaca'),
              backgroundColor: Color(0xFF0EA5A4),
              duration: Duration(seconds: 2),
            ),
          );
          return;
        }
        _removeNotification(notification.id);
      },
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF0EA5A4),
          borderRadius: BorderRadius.circular(18),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 18),
        alignment: Alignment.centerLeft,
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.mark_email_read_rounded, color: Colors.white),
            SizedBox(width: 8),
            Text(
              'Tandai Dibaca',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
      secondaryBackground: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFDC2626),
          borderRadius: BorderRadius.circular(18),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 18),
        alignment: Alignment.centerRight,
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Sembunyikan',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(width: 8),
            Icon(Icons.delete_outline_rounded, color: Colors.white),
          ],
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: notification.isRead
                ? const Color(0xFFE2E8F0)
                : visual.color.withValues(alpha: 0.35),
          ),
          boxShadow: [
            BoxShadow(
              color: visual.color.withValues(alpha: 0.12),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () async {
              if (!notification.isRead) {
                await _markNotificationAsRead(notification.id);
              }
              if (!mounted) return;
              _showNotificationDetail(notification);
            },
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          visual.color,
                          visual.color.withValues(alpha: 0.82),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(visual.icon, color: Colors.white, size: 24),
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
                              child: Text(
                                notification.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: notification.isRead
                                      ? FontWeight.w600
                                      : FontWeight.w800,
                                  color: const Color(0xFF0F172A),
                                ),
                              ),
                            ),
                            if (!notification.isRead)
                              Container(
                                margin: const EdgeInsets.only(left: 8, top: 3),
                                width: 10,
                                height: 10,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF10B981),
                                  shape: BoxShape.circle,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          notification.message,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            height: 1.45,
                            color: Color(0xFF475569),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            _buildTag(
                              label: visual.label,
                              textColor: visual.color,
                              bgColor: visual.softColor,
                              icon: visual.icon,
                            ),
                            _buildTag(
                              label: _priorityLabel(notification.priority),
                              textColor: _priorityColor(notification.priority),
                              bgColor: _priorityColor(
                                notification.priority,
                              ).withValues(alpha: 0.14),
                              icon: Icons.flag_rounded,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(
                              Icons.schedule_rounded,
                              size: 14,
                              color: Color(0xFF94A3B8),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _formatDate(notification.date),
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF94A3B8),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const Spacer(),
                            Icon(
                              Icons.arrow_forward_ios_rounded,
                              size: 12,
                              color: Colors.grey[400],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTag({
    required String label,
    required Color textColor,
    required Color bgColor,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: textColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 1) {
      return 'Baru saja';
    }
    if (difference.inHours < 1) {
      return '${difference.inMinutes} menit lalu';
    }
    if (difference.inDays < 1) {
      return '${difference.inHours} jam lalu';
    }
    if (difference.inDays < 7) {
      return '${difference.inDays} hari lalu';
    }
    return DateFormat('dd MMM yyyy, HH:mm', 'id_ID').format(date);
  }

  void _showNotificationDetail(NotificationItem notification) {
    final visual = _visualForType(notification.type);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Center(
                      child: Container(
                        width: 46,
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFFCBD5E1),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            visual.color,
                            visual.color.withValues(alpha: 0.84),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(visual.icon, color: Colors.white),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  visual.label,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _priorityLabel(notification.priority),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white.withValues(alpha: 0.88),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      notification.title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      DateFormat(
                        'EEEE, dd MMMM yyyy - HH:mm',
                        'id_ID',
                      ).format(notification.date),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Text(
                        notification.message,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF334155),
                          height: 1.6,
                        ),
                      ),
                    ),
                    if (notification.actionUrl?.trim().isNotEmpty == true) ...[
                      const SizedBox(height: 14),
                      const Text(
                        'Link Terkait',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF475569),
                        ),
                      ),
                      const SizedBox(height: 6),
                      SelectableText(
                        notification.actionUrl!.trim(),
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF0EA5A4),
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ],
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(modalContext),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0EA5A4),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text(
                          'Tutup',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  NotificationItem _mapDbNotification(DbNotification notification) {
    final date = notification.createdAt ?? DateTime.now();
    return NotificationItem(
      id:
          notification.id ??
          'notif-${date.millisecondsSinceEpoch}-${notification.title.hashCode}',
      title: notification.title,
      message: notification.message,
      date: date,
      type: _mapNotificationType(notification.type),
      isRead: notification.isRead,
      priority: notification.priority,
      imageUrl: notification.imageUrl,
      actionUrl: notification.actionUrl,
      metadata: notification.metadata,
    );
  }

  NotificationType _mapNotificationType(String type) {
    final value = type.toLowerCase();
    if (value.contains('kta')) {
      return NotificationType.ktaExpired;
    }
    if (value.contains('payment') ||
        value.contains('iuran') ||
        value.contains('monthly')) {
      return NotificationType.monthlyFee;
    }
    if (value.contains('competition') || value.contains('lomba')) {
      return NotificationType.competition;
    }
    return NotificationType.general;
  }

  _NotificationVisual _visualForType(NotificationType type) {
    switch (type) {
      case NotificationType.ktaExpired:
        return const _NotificationVisual(
          icon: Icons.badge_rounded,
          label: 'KTA',
          color: Color(0xFFEF4444),
          softColor: Color(0xFFFFE4E6),
        );
      case NotificationType.monthlyFee:
        return const _NotificationVisual(
          icon: Icons.account_balance_wallet_rounded,
          label: 'Pembayaran',
          color: Color(0xFFF59E0B),
          softColor: Color(0xFFFFF4D6),
        );
      case NotificationType.competition:
        return const _NotificationVisual(
          icon: Icons.emoji_events_rounded,
          label: 'Lomba',
          color: Color(0xFF8B5CF6),
          softColor: Color(0xFFEDE9FE),
        );
      case NotificationType.general:
        return const _NotificationVisual(
          icon: Icons.campaign_rounded,
          label: 'Umum',
          color: Color(0xFF0EA5E9),
          softColor: Color(0xFFE0F2FE),
        );
    }
  }

  Color _priorityColor(String priority) {
    final normalized = priority.toLowerCase();
    if (normalized == 'urgent') {
      return const Color(0xFFB91C1C);
    }
    if (normalized == 'high') {
      return const Color(0xFFDC2626);
    }
    if (normalized == 'low') {
      return const Color(0xFF334155);
    }
    return const Color(0xFF0F766E);
  }

  String _priorityLabel(String priority) {
    switch (priority.toLowerCase()) {
      case 'urgent':
        return 'Prioritas Urgent';
      case 'high':
        return 'Prioritas Tinggi';
      case 'low':
        return 'Prioritas Rendah';
      default:
        return 'Prioritas Normal';
    }
  }

  String _emptyMessageByFilter() {
    switch (_activeFilter) {
      case NotificationFilter.all:
        return 'Belum ada notifikasi terbaru dari admin saat ini.';
      case NotificationFilter.unread:
        return 'Semua notifikasi sudah dibaca.';
      case NotificationFilter.kta:
        return 'Belum ada notifikasi terkait KTA.';
      case NotificationFilter.monthlyFee:
        return 'Belum ada notifikasi terkait pembayaran.';
      case NotificationFilter.competition:
        return 'Belum ada pengumuman pendaftaran atau update lomba.';
      case NotificationFilter.general:
        return 'Belum ada informasi umum terbaru.';
    }
  }
}

class _FilterChipData {
  final NotificationFilter filter;
  final String label;
  final IconData icon;

  const _FilterChipData(this.filter, this.label, this.icon);
}

class _NotificationVisual {
  final IconData icon;
  final String label;
  final Color color;
  final Color softColor;

  const _NotificationVisual({
    required this.icon,
    required this.label,
    required this.color,
    required this.softColor,
  });
}
