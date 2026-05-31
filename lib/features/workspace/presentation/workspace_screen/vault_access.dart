part of '../workspace_screen.dart';

const int _recoveryCodePromptFailureThreshold = 2;
const String _vaultResetConfirmationPhrase = 'RESET VAULT';

class _VaultAccessSurface extends ConsumerStatefulWidget {
  const _VaultAccessSurface({this.session, this.error});

  final VaultSessionState? session;
  final Object? error;

  @override
  ConsumerState<_VaultAccessSurface> createState() =>
      _VaultAccessSurfaceState();
}

class _VaultAccessSurfaceState extends ConsumerState<_VaultAccessSurface>
    with TickerProviderStateMixin {
  final TextEditingController _passphraseController = TextEditingController();
  String? _localErrorMessage;

  late final AnimationController _shakeController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 480),
  );
  String? _lastShownError;

  @override
  void dispose() {
    _passphraseController.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  void _triggerShake(String? errorMessage) {
    if (errorMessage == null || errorMessage == _lastShownError) {
      _lastShownError = errorMessage;
      return;
    }
    _lastShownError = errorMessage;
    _shakeController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.tokens;
    final asyncState = ref.watch(vaultSessionControllerProvider);
    final session = asyncState.value ?? widget.session;
    final isInitializing = session?.vaultState == VaultState.uninitialized;
    final recoveryKey = session?.recoveryKey;
    final showRecoveryCodeAccess =
        !isInitializing &&
        (session?.unlockFailureCount ?? 0) >=
            _recoveryCodePromptFailureThreshold;
    final errorMessage =
        _localErrorMessage ??
        session?.failureMessage ??
        (asyncState.hasError ? asyncState.error.toString() : null) ??
        widget.error?.toString();

    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _triggerShake(errorMessage),
    );

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: EntranceFade(
          offsetY: 24,
          beginScale: 0.94,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: AnimatedBuilder(
              animation: _shakeController,
              builder: (context, child) {
                // Damped oscillation: amplitude decays as the controller runs.
                final decay = 1 - _shakeController.value;
                final dx = decay * 10 * _sineShake(_shakeController.value);
                return Transform.translate(offset: Offset(dx, 0), child: child);
              },
              child: GlassPanel(
                elevation: 28,
                padding: const EdgeInsets.fromLTRB(32, 36, 32, 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _VaultLockBadge(initializing: isInitializing),
                    const SizedBox(height: 22),
                    Text(
                      isInitializing ? l10n.vaultCreateTitle : l10n.vaultUnlockTitle,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: t.textPrimary,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      isInitializing
                          ? l10n.vaultCreateSubtitle
                          : l10n.vaultUnlockSubtitle,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: t.textSecondary,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 24),
                    SerlinkTextField(
                      key: const ValueKey('vault-passphrase-field'),
                      controller: _passphraseController,
                      obscureText: true,
                      autofocus: true,
                      decoration: InputDecoration(
                        labelText: isInitializing
                            ? l10n.vaultNewPassphraseLabel
                            : l10n.vaultPassphraseLabel,
                        prefixIcon: const Icon(Icons.lock_outline, size: 19),
                      ),
                      onSubmitted: (_) => _submit(isInitializing),
                    ),
                    const SizedBox(height: 14),
                    _VaultPrimaryButton(
                      key: const ValueKey('vault-submit-button'),
                      label: isInitializing
                          ? l10n.vaultCreateAction
                          : l10n.vaultUnlockAction,
                      loading: asyncState.isLoading,
                      onPressed: asyncState.isLoading
                          ? null
                          : () => _submit(isInitializing),
                    ),
                    if (!isInitializing &&
                        session?.localUnlockAvailable == true) ...[
                      const SizedBox(height: 10),
                      SerlinkOutlinedButton.icon(
                        key: const ValueKey('vault-local-unlock-button'),
                        onPressed: asyncState.isLoading
                            ? null
                            : () => ref
                                  .read(vaultSessionControllerProvider.notifier)
                                  .unlockWithLocalKey(),
                        icon: const Icon(Icons.fingerprint, size: 19),
                        label: Text(l10n.vaultUnlockWithDeviceAction),
                      ),
                    ],
                    if (showRecoveryCodeAccess) ...[
                      const SizedBox(height: 10),
                      SerlinkTextButton.icon(
                        key: const ValueKey('vault-recovery-code-button'),
                        onPressed: asyncState.isLoading
                            ? null
                            : _showRecoveryCodeDialog,
                        icon: const Icon(Icons.key_outlined, size: 19),
                        label: Text(l10n.vaultUseRecoveryCodeAction),
                      ),
                    ],
                    _VaultErrorText(message: errorMessage),
                    if (recoveryKey != null) ...[
                      const SizedBox(height: 20),
                      SelectableText(recoveryKey.value),
                      const SizedBox(height: 8),
                      SerlinkOutlinedButton(
                        onPressed: () => ref
                            .read(vaultSessionControllerProvider.notifier)
                            .dismissRecoveryKey(),
                        child: Text(l10n.doneAction),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showRecoveryCodeDialog() {
    return _showVaultRecoveryCodeDialog(context);
  }

  void _submit(bool isInitializing) {
    final passphrase = _passphraseController.text;
    if (passphrase.isEmpty) {
      setState(() {
        _localErrorMessage = context.l10n.vaultPassphraseRequired;
      });
      return;
    }
    setState(() {
      _localErrorMessage = null;
    });
    if (isInitializing) {
      ref
          .read(vaultSessionControllerProvider.notifier)
          .initialize(passphrase: passphrase);
    } else {
      ref
          .read(vaultSessionControllerProvider.notifier)
          .unlock(passphrase: passphrase);
    }
  }
}

/// Damped sine used to make the error-shake oscillate a few times then settle.
double _sineShake(double v) {
  // 3 oscillations across the animation.
  return math.sin(v * math.pi * 6);
}

/// Compact vault badge: a small rounded gradient tile with a soft accent halo
/// that scales up and fades once on mount, while the tile springs in. One-shot
/// (plays once) so it stays friendly to `pumpAndSettle` in widget tests.
class _VaultLockBadge extends StatefulWidget {
  const _VaultLockBadge({required this.initializing});

  final bool initializing;

  @override
  State<_VaultLockBadge> createState() => _VaultLockBadgeState();
}

class _VaultLockBadgeState extends State<_VaultLockBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  late final Animation<double> _badgeScale = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0, 0.6, curve: Curves.easeOutBack),
  );
  late final Animation<double> _halo = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.1, 1, curve: Curves.easeOut),
  );

  @override
  void initState() {
    super.initState();
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Center(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final haloValue = _halo.value;
          return Stack(
            alignment: Alignment.center,
            children: [
              // Soft expanding halo — no hard frame, just a glow that settles.
              Opacity(
                opacity: (1 - haloValue) * 0.5,
                child: Transform.scale(
                  scale: 0.7 + haloValue * 1.1,
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          t.accentPrimary.withValues(alpha: 0.55),
                          t.accentPrimary.withValues(alpha: 0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Transform.scale(
                scale: _badgeScale.value.clamp(0.0, 1.2),
                child: child,
              ),
            ],
          );
        },
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            gradient: serlinkAccentGradient(t),
            borderRadius: const BorderRadius.all(Radius.circular(16)),
            boxShadow: [
              BoxShadow(
                color: t.accentStrong.withValues(alpha: 0.4),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Icon(
            widget.initializing
                ? Icons.shield_moon_outlined
                : Icons.lock_rounded,
            size: 26,
            color: t.onAccent,
          ),
        ),
      ),
    );
  }
}

/// Full-width primary action with a gradient fill and inline loading spinner.
class _VaultPrimaryButton extends StatelessWidget {
  const _VaultPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final enabled = onPressed != null;
    return Opacity(
      opacity: enabled ? 1 : 0.6,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: serlinkAccentGradient(t),
          borderRadius: SerlinkRadii.control,
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: t.accentStrong.withValues(alpha: 0.45),
                    blurRadius: 20,
                    offset: const Offset(0, 9),
                  ),
                ]
              : null,
        ),
        child: SerlinkPressable(
          onTap: onPressed,
          borderRadius: SerlinkRadii.control,
          hoverColor: Colors.white.withValues(alpha: 0.06),
          pressedColor: Colors.black.withValues(alpha: 0.08),
          child: SizedBox(
            height: 46,
            child: Center(
              child: loading
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        valueColor: AlwaysStoppedAnimation(t.onAccent),
                      ),
                    )
                  : Text(
                      label,
                      style: TextStyle(
                        color: t.onAccent,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Animated error line that fades/slides in below the form.
class _VaultErrorText extends StatelessWidget {
  const _VaultErrorText({required this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      alignment: Alignment.topCenter,
      child: message == null
          ? const SizedBox(width: double.infinity)
          : Padding(
              padding: const EdgeInsets.only(top: 14),
              child: SerlinkAlert.danger(message: message, compact: true),
            ),
    );
  }
}
