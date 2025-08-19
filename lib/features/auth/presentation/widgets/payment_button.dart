import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:roda/core/models/class_instance.dart';
import 'package:roda/core/models/schedule_template.dart';
import 'package:roda/core/utils/venmo_helper.dart';
import 'package:roda/features/groups/providers/supabase_group_providers.dart';
import 'package:roda/features/teacher/providers/supabase_schedule_providers.dart';
import 'package:intl/intl.dart';

class PaymentButton extends ConsumerStatefulWidget {
  final dynamic classData; // TODO: Replace with proper ClassInstance type
  final String userId;
  
  const PaymentButton({
    super.key,
    required this.classData,
    required this.userId,
  });
  
  @override
  ConsumerState<PaymentButton> createState() => _PaymentButtonState();
}

class _PaymentButtonState extends ConsumerState<PaymentButton> {
  bool _venmoClicked = false;
  bool _isProcessing = false;
  
  @override
  void initState() {
    super.initState();
    // Check if user has already confirmed payment
    final paymentInfo = widget.classData.instance.paymentConfirmations[widget.userId];
    if (paymentInfo != null && paymentInfo.status == PaymentStatus.confirmed) {
      _venmoClicked = true; // Show as confirmed
    }
  }
  
  Future<void> _handleVenmoPayment() async {
    // Get the group's Venmo handle - always fetch latest data
    final groupAsyncValue = ref.read(groupByIdProvider(widget.classData.template.groupId));
    
    final group = groupAsyncValue.when(
      data: (data) => data,
      loading: () => null,
      error: (_, __) => null,
    );
    
    if (group == null || group.venmoHandle == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment information not available'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }
    
    final eventType = widget.classData.eventType == EventType.roda ? 'Roda' : 'Class';
    final dateStr = DateFormat('MMM d').format(widget.classData.scheduledDate);
    final note = '$eventType - $dateStr - ${widget.classData.groupName}';
    
    final success = await VenmoHelper.launchVenmoPayment(
      venmoHandle: group.venmoHandle!,
      amount: widget.classData.price,
      note: note,
    );
    
    if (success) {
      setState(() {
        _venmoClicked = true;
      });
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open Venmo'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  Future<void> _confirmPayment() async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Payment'),
        content: Text(
          'I confirm that I paid \$${widget.classData.price?.toStringAsFixed(2) ?? "0.00"} for this ${widget.classData.eventType == EventType.roda ? "roda" : "class"}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
            ),
            child: const Text('Confirm Payment'),
          ),
        ],
      ),
    );
    
    if (confirmed != true) return;
    
    setState(() {
      _isProcessing = true;
    });
    
    try {
      // TODO: Update the payment confirmation in Supabase
      // Need to update the class_instances table with payment confirmation
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment confirmed! Thank you.'),
            backgroundColor: Colors.green,
          ),
        );
      }
      
      // Refresh the data
      ref.invalidate(userRegisteredClassesProvider(widget.userId));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to confirm payment: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    // Check current payment status
    final paymentInfo = widget.classData.instance.paymentConfirmations[widget.userId];
    final isConfirmed = paymentInfo?.status == PaymentStatus.confirmed;
    
    if (isConfirmed) {
      // Show confirmed status
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, size: 14, color: Colors.green[700]),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                'Paid',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.green[700],
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    }
    
    if (!_venmoClicked) {
      // Show initial Venmo payment button
      return OutlinedButton.icon(
        onPressed: _handleVenmoPayment,
        icon: const Icon(Icons.attach_money, size: 18),
        label: const Text('Pay with Venmo'),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.green[700],
          side: BorderSide(color: Colors.green.shade400),
          padding: const EdgeInsets.symmetric(vertical: 8),
        ),
      );
    } else {
      // Show confirm button after Venmo was clicked
      return ElevatedButton.icon(
        onPressed: _isProcessing ? null : _confirmPayment,
        icon: _isProcessing 
            ? const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Icon(Icons.check, size: 16),
        label: Text(_isProcessing ? 'Processing...' : 'Confirm'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green[600],
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          textStyle: const TextStyle(fontSize: 13),
        ),
      );
    }
  }
}