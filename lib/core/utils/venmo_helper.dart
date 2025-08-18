import 'package:url_launcher/url_launcher.dart';

class VenmoHelper {
  // Generate Venmo deep link URL
  static String generateVenmoUrl({
    required String venmoHandle,
    double? amount,
    String? note,
  }) {
    // Remove @ if it exists
    final cleanHandle = venmoHandle.startsWith('@') 
        ? venmoHandle.substring(1) 
        : venmoHandle;
    
    // Build the Venmo URL
    String url = 'venmo://paycharge?txn=pay&recipients=$cleanHandle';
    
    if (amount != null && amount > 0) {
      url += '&amount=${amount.toStringAsFixed(2)}';
    }
    
    if (note != null && note.isNotEmpty) {
      final encodedNote = Uri.encodeComponent(note);
      url += '&note=$encodedNote';
    }
    
    return url;
  }
  
  // Launch Venmo app with payment
  static Future<bool> launchVenmoPayment({
    required String venmoHandle,
    double? amount,
    String? note,
  }) async {
    // Remove @ if it exists for clean handle
    final cleanHandle = venmoHandle.startsWith('@') 
        ? venmoHandle.substring(1) 
        : venmoHandle;
    
    // Try native app first for both iOS and Android
    final venmoUrl = generateVenmoUrl(
      venmoHandle: venmoHandle,
      amount: amount,
      note: note,
    );
    
    final uri = Uri.parse(venmoUrl);
    
    try {
      // Try to launch the Venmo app directly
      // This will attempt to open the app if installed
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      
      if (launched) {
        return true;
      }
    } catch (e) {
      print('Could not launch Venmo app: $e');
      // Continue to web fallback
    }
    
    // Fallback to web URL with proper parameters
    String webUrl = 'https://venmo.com/$cleanHandle';
    
    // Add payment parameters if amount is specified
    if (amount != null && amount > 0) {
      webUrl = 'https://account.venmo.com/pay?recipients=$cleanHandle';
      webUrl += '&amount=${amount.toStringAsFixed(2)}';
      
      if (note != null && note.isNotEmpty) {
        final encodedNote = Uri.encodeComponent(note);
        webUrl += '&note=$encodedNote';
      }
    }
    
    final webUri = Uri.parse(webUrl);
    
    try {
      return await launchUrl(
        webUri,
        mode: LaunchMode.externalApplication,
      );
    } catch (e) {
      print('Could not launch Venmo web: $e');
      return false;
    }
  }
}