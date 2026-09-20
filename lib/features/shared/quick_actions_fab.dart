import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import 'quick_action_dialogs.dart';

class QuickActionsFab extends ConsumerStatefulWidget {
  const QuickActionsFab({super.key});

  @override
  ConsumerState<QuickActionsFab> createState() => _QuickActionsFabState();
}

class _QuickActionsFabState extends ConsumerState<QuickActionsFab>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _expandAnimation;
  bool _isOpen = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      value: _isOpen ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _expandAnimation = CurvedAnimation(
      curve: Curves.fastOutSlowIn,
      reverseCurve: Curves.easeOutQuad,
      parent: _controller,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() {
      _isOpen = !_isOpen;
      if (_isOpen) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    });
  }

  void _close() {
    if (_isOpen) {
      setState(() {
        _isOpen = false;
        _controller.reverse();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (_isOpen) ...[
          _buildActionItem(
            label: 'Record Payment',
            icon: Icons.arrow_downward,
            color: AppColors.paymentText,
            bgColor: AppColors.paymentBg,
            onTap: () {
              _close();
              showRecordPaymentDialog(context, ref);
            },
          ),
          const SizedBox(height: 10),
          _buildActionItem(
            label: 'Add Baki',
            icon: Icons.arrow_upward,
            color: AppColors.debtText,
            bgColor: AppColors.debtBg,
            onTap: () {
              _close();
              showAddBakiDialog(context, ref);
            },
          ),
          const SizedBox(height: 10),
          _buildActionItem(
            label: 'Add Customer',
            icon: Icons.person_add_alt_1,
            color: AppColors.primary,
            bgColor: AppColors.primaryContainer,
            onTap: () {
              _close();
              showAddCustomerDialog(context, ref);
            },
          ),
          const SizedBox(height: 12),
        ],
        FloatingActionButton(
          heroTag: 'speed_dial_main_fab',
          onPressed: _toggle,
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape: const CircleBorder(),
          child: RotationTransition(
            turns: Tween<double>(begin: 0.0, end: 0.125).animate(_expandAnimation),
            child: Icon(_isOpen ? Icons.add : Icons.add, size: 28),
          ),
        ),
      ],
    );
  }

  Widget _buildActionItem({
    required String label,
    required IconData icon,
    required Color color,
    required Color bgColor,
    required VoidCallback onTap,
  }) {
    return FadeTransition(
      opacity: _expandAnimation,
      child: ScaleTransition(
        scale: _expandAnimation,
        alignment: Alignment.centerRight,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Material(
              color: Colors.white,
              elevation: 3,
              borderRadius: BorderRadius.circular(8),
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Text(
                    label,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            FloatingActionButton.small(
              heroTag: 'fab_$label',
              onPressed: onTap,
              backgroundColor: bgColor,
              foregroundColor: color,
              shape: const CircleBorder(),
              elevation: 3,
              child: Icon(icon, size: 20),
            ),
          ],
        ),
      ),
    );
  }
}
