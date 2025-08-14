// Simple Cloudflare Worker for R2 uploads
// This version uses the R2 binding directly

export default {
  async fetch(request, env) {
    // CORS headers for Flutter app
    const corsHeaders = {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'POST, GET, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type, Authorization',
    };

    // Handle CORS preflight
    if (request.method === 'OPTIONS') {
      return new Response(null, { headers: corsHeaders });
    }

    // Simple API key check
    const authHeader = request.headers.get('Authorization');
    const expectedKey = env.UPLOAD_API_KEY || 'roda_upload_2024_secure'; // Set in environment
    
    if (!authHeader || authHeader !== `Bearer ${expectedKey}`) {
      return new Response(JSON.stringify({ error: 'Unauthorized' }), { 
        status: 401,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      });
    }

    if (request.method !== 'POST') {
      return new Response(JSON.stringify({ error: 'Method not allowed' }), { 
        status: 405,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      });
    }

    try {
      const formData = await request.formData();
      const file = formData.get('file');
      const userId = formData.get('userId');
      const type = formData.get('type') || 'profile_picture';

      if (!file || !userId) {
        return new Response(JSON.stringify({ error: 'Missing file or userId' }), { 
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        });
      }

      // Generate filename
      const timestamp = Date.now();
      const fileExt = file.name.split('.').pop() || 'jpg';
      const filename = `profiles/${userId}/avatar_${timestamp}.${fileExt}`;
      
      // Upload to R2
      await env.RODA_BUCKET.put(filename, file.stream(), {
        httpMetadata: {
          contentType: file.type || 'image/jpeg',
        },
        customMetadata: {
          userId: userId,
          uploadedAt: new Date().toISOString(),
        },
      });

      // Return the public URL
      const publicUrl = `https://pub-332d53d6ee8c469a9306eae69acfceb0.r2.dev/${filename}`;
      
      return new Response(JSON.stringify({ 
        success: true, 
        url: publicUrl,
        filename: filename,
      }), {
        status: 200,
        headers: {
          ...corsHeaders,
          'Content-Type': 'application/json',
        },
      });
    } catch (error) {
      console.error('Upload error:', error);
      return new Response(JSON.stringify({ 
        error: 'Upload failed',
        message: error.message 
      }), {
        status: 500,
        headers: {
          ...corsHeaders,
          'Content-Type': 'application/json',
        },
      });
    }
  },
};