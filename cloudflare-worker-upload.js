// Cloudflare Worker for handling R2 uploads
// Deploy this to Cloudflare Workers and update the URL in r2_config.dart

export default {
  async fetch(request, env) {
    // CORS headers
    const corsHeaders = {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'POST, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type, Authorization',
    };

    // Handle CORS preflight
    if (request.method === 'OPTIONS') {
      return new Response(null, { headers: corsHeaders });
    }

    // Check authorization
    const authHeader = request.headers.get('Authorization');
    const expectedKey = env.UPLOAD_API_KEY; // Set this in Workers environment variables
    
    if (!authHeader || authHeader !== `Bearer ${expectedKey}`) {
      return new Response('Unauthorized', { 
        status: 401,
        headers: corsHeaders 
      });
    }

    if (request.method !== 'POST') {
      return new Response('Method not allowed', { 
        status: 405,
        headers: corsHeaders 
      });
    }

    try {
      const formData = await request.formData();
      const file = formData.get('file');
      const userId = formData.get('userId');
      const type = formData.get('type');

      if (!file || !userId) {
        return new Response('Missing required fields', { 
          status: 400,
          headers: corsHeaders 
        });
      }

      // Get the filename from the form data
      const filename = file.name || `${userId}_${Date.now()}`;
      
      // Upload to R2
      const object = await env.R2_BUCKET.put(filename, file.stream(), {
        httpMetadata: {
          contentType: file.type || 'application/octet-stream',
        },
        customMetadata: {
          userId: userId,
          type: type || 'profile_picture',
          uploadedAt: new Date().toISOString(),
        },
      });

      // Return the public URL
      const publicUrl = `${env.PUBLIC_BUCKET_URL}/${filename}`;
      
      return new Response(JSON.stringify({ 
        success: true, 
        url: publicUrl,
        key: object.key,
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

// Environment variables to set in Cloudflare Workers:
// - UPLOAD_API_KEY: Your secret API key
// - R2_BUCKET: Your R2 bucket binding
// - PUBLIC_BUCKET_URL: Your public bucket URL or custom domain