import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_space.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../auth/data/models/user_model.dart';
import '../../../auth/providers/auth_controller.dart';
import '../../../shared/widgets/app_avatar.dart';
import '../../../shared/widgets/app_feedback.dart';
import '../../../shared/widgets/app_states.dart';
import '../../data/models/ride_message_model.dart';
import '../../providers/rides_providers.dart';

/// Live chat between the client and their driver, for the active ride.
///
/// Opens once a driver is assigned; becomes read-only when the ride ends so the
/// history stays available.
class RideChatScreen extends ConsumerStatefulWidget {
  const RideChatScreen({super.key});

  @override
  ConsumerState<RideChatScreen> createState() => _RideChatScreenState();
}

class _RideChatScreenState extends ConsumerState<RideChatScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  bool _sending = false;
  int _lastCount = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(rideChatProvider.notifier).markRead();
    });
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToEnd({bool animate = true}) {
    if (!_scroll.hasClients) return;
    final target = _scroll.position.maxScrollExtent;
    if (animate) {
      _scroll.animateTo(target, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    } else {
      _scroll.jumpTo(target);
    }
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    _input.clear();
    try {
      await ref.read(rideChatProvider.notifier).send(text);
      HapticFeedback.selectionClick();
    } catch (e) {
      if (mounted) AppToast.apiError(context, e);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final chat = ref.watch(rideChatProvider);
    final ride = ref.watch(currentRideProvider).value;
    final me = ref.watch(currentUserProvider);
    final isDriver = me?.role == UserRole.driver;
    final peer = isDriver ? ride?.client : ride?.driver;
    final closed = ride == null || !ride.status.hasDriver;

    // Keep the newest message in view, and mark arrivals as read while open.
    ref.listen(rideChatProvider, (prev, next) {
      final count = next.value?.length ?? 0;
      if (count != _lastCount) {
        _lastCount = count;
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToEnd());
        ref.read(rideChatProvider.notifier).markRead();
      }
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            AppAvatar(username: peer?.name ?? '?', size: 38),
            const SizedBox(width: AppSpace.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    peer?.name ?? (isDriver ? 'Client' : 'Chauffeur'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.h3,
                  ),
                  Text(
                    closed ? 'Course terminée' : (ride.status.label),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.caption.copyWith(color: AppColors.muted),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          if ((peer?.phone ?? '').isNotEmpty)
            IconButton(
              tooltip: 'Appeler',
              icon: const Icon(Icons.phone_rounded),
              onPressed: () => AppToast.info(context, 'Appeler ${peer!.phone}'),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: chat.when(
              loading: () => const LoadingView(message: 'Chargement de la conversation…'),
              error: (e, _) => ErrorView(
                message: '$e',
                onRetry: () => ref.invalidate(rideChatProvider),
              ),
              data: (messages) {
                if (messages.isEmpty) {
                  return EmptyView(
                    icon: Icons.forum_rounded,
                    title: closed ? 'Aucun message' : 'Démarrez la conversation',
                    message: closed
                        ? "Cette course s'est terminée sans message."
                        : isDriver
                        ? 'Prévenez le client de votre arrivée ou demandez un repère.'
                        : 'Indiquez un repère à votre chauffeur pour le trouver plus vite.',
                  );
                }
                return ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(AppSpace.md, AppSpace.md, AppSpace.md, AppSpace.xs),
                  itemCount: messages.length,
                  itemBuilder: (_, i) {
                    final m = messages[i];
                    final previous = i == 0 ? null : messages[i - 1];
                    final showDay = previous == null ||
                        !_sameDay(previous.createdAt, m.createdAt);
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (showDay) _DaySeparator(date: m.createdAt),
                        _Bubble(
                          message: m,
                          onRetry: () => ref.read(rideChatProvider.notifier).retry(m),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
          _Composer(
            controller: _input,
            enabled: !closed,
            sending: _sending,
            onSend: _send,
            closedNotice: closed
                ? 'La course est terminée — la conversation est en lecture seule.'
                : null,
          ),
        ],
      ),
    );
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class _DaySeparator extends StatelessWidget {
  const _DaySeparator({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isToday = date.year == now.year && date.month == now.month && date.day == now.day;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpace.sm),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: AppColors.line.withValues(alpha: .7),
            borderRadius: AppRadius.rPill,
          ),
          child: Text(
            isToday ? "Aujourd'hui" : DateFormat('dd/MM/yyyy').format(date),
            style: AppTypography.caption.copyWith(color: AppColors.inkSoft),
          ),
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message, required this.onRetry});

  /// Tail corner: tighter than any AppRadius token so the bubble points at its author.
  static const _tail = Radius.circular(5);

  final RideMessage message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final mine = message.isMine;
    final failed = message.failed;

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * .78),
        child: Container(
          margin: const EdgeInsets.only(bottom: AppSpace.xs),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: failed
                ? AppColors.dangerSoft
                : mine
                ? AppColors.brand
                : AppColors.surface,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(AppRadius.lg),
              topRight: const Radius.circular(AppRadius.lg),
              bottomLeft: mine ? const Radius.circular(AppRadius.lg) : _tail,
              bottomRight: mine ? _tail : const Radius.circular(AppRadius.lg),
            ),
            border: mine ? null : Border.all(color: AppColors.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                message.body,
                style: AppTypography.body.copyWith(
                  color: mine && !failed ? AppColors.ink : AppColors.ink,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 3),
              Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (failed) ...[
                    GestureDetector(
                      onTap: onRetry,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.refresh_rounded, size: 13, color: AppColors.danger),
                          const SizedBox(width: 3),
                          Text(
                            'Réessayer',
                            style: AppTypography.caption.copyWith(
                              color: AppColors.danger,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    Text(
                      DateFormat('HH:mm').format(message.createdAt),
                      style: AppTypography.caption.copyWith(
                        fontSize: 11,
                        color: mine ? AppColors.ink.withValues(alpha: .6) : AppColors.muted,
                      ),
                    ),
                    if (mine) ...[
                      const SizedBox(width: 4),
                      Icon(
                        message.pending
                            ? Icons.schedule_rounded
                            : message.isRead
                            ? Icons.done_all_rounded
                            : Icons.check_rounded,
                        size: 14,
                        color: message.isRead
                            ? AppColors.emeraldDeep
                            : AppColors.ink.withValues(alpha: .55),
                      ),
                    ],
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.enabled,
    required this.sending,
    required this.onSend,
    this.closedNotice,
  });

  final TextEditingController controller;
  final bool enabled;
  final bool sending;
  final VoidCallback onSend;
  final String? closedNotice;

  @override
  Widget build(BuildContext context) {
    if (!enabled) {
      return Container(
        width: double.infinity,
        padding: EdgeInsets.fromLTRB(
          AppSpace.md,
          AppSpace.sm,
          AppSpace.md,
          AppSpace.sm + MediaQuery.of(context).padding.bottom,
        ),
        color: AppColors.surfaceAlt,
        child: Row(
          children: [
            const Icon(Icons.lock_outline_rounded, size: 16, color: AppColors.muted),
            const SizedBox(width: AppSpace.xs),
            Expanded(
              child: Text(
                closedNotice ?? 'Conversation fermée.',
                style: AppTypography.caption.copyWith(color: AppColors.muted),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSpace.sm,
        AppSpace.xs,
        AppSpace.sm,
        AppSpace.xs + MediaQuery.of(context).padding.bottom,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              minLines: 1,
              maxLines: 4,
              maxLength: 1000,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => onSend(),
              decoration: const InputDecoration(
                hintText: 'Écrire un message…',
                counterText: '',
                filled: true,
                fillColor: AppColors.surfaceAlt,
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
          const SizedBox(width: AppSpace.xs),
          _SendButton(sending: sending, onTap: onSend),
        ],
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  const _SendButton({required this.sending, required this.onTap});

  final bool sending;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: sending ? null : onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          gradient: AppColors.brandGradient,
          borderRadius: AppRadius.rPill,
        ),
        child: Center(
          child: sending
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2.2, color: AppColors.ink),
                )
              : const Icon(Icons.send_rounded, color: AppColors.ink, size: 21),
        ),
      ),
    );
  }
}
