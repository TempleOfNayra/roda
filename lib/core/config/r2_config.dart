class R2Config {
  // R2 Bucket Configuration for 'roda' bucket
  
  // Your R2 endpoint (from your account)
  static const String r2Endpoint = 'https://51b7b84d1d721e998fdea17b2c097382.r2.cloudflarestorage.com';
  
  // Public URL for reading images (now enabled!)
  static const String publicBucketUrl = 'https://pub-332d53d6ee8c469a9306eae69acfceb0.r2.dev';
  
  // Worker URL for uploads
  static const String uploadWorkerUrl = 'https://rodabucket.thefool-51b.workers.dev';
  
  // API key for your upload worker (must match the UPLOAD_API_KEY in your Worker environment)
  // Using fallback key from Worker: 'roda_upload_2024_secure'
  static const String uploadApiKey = 'roda_upload_2024_secure';
  
  // For direct upload (you'll need R2 API tokens)
  // Get these from: R2 → Manage R2 API Tokens → Create API Token
  static const String accessKeyId = ''; // Don't commit with real values!
  static const String secretAccessKey = ''; // Don't commit with real values!
  static const String bucketName = 'roda';
}