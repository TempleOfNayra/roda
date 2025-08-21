export default {
  async fetch(request, env) {
    // CORS headers
    const corsHeaders = {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'POST, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type, Authorization',
    };

    // Handle preflight requests
    if (request.method === 'OPTIONS') {
      return new Response(null, { headers: corsHeaders });
    }

    // Only accept POST requests
    if (request.method !== 'POST') {
      return new Response(JSON.stringify({ error: 'Method not allowed' }), {
        status: 405,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    try {
      // Check authorization
      const authHeader = request.headers.get('Authorization');
      const expectedKey = env.UPLOAD_API_KEY || 'roda_upload_2024_secure';

      if (!authHeader || authHeader !== `Bearer ${expectedKey}`) {
        return new Response(JSON.stringify({ error: 'Unauthorized' }), {
          status: 401,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        });
      }

      // Parse the multipart form data
      const formData = await request.formData();
      const file = formData.get('file');
      const path = formData.get('path');

      // Validate required fields
      if (!file) {
        return new Response(JSON.stringify({ error: 'Missing file' }), {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        });
      }

      if (!path) {
        return new Response(JSON.stringify({ error: 'Missing path parameter' }), {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        });
      }

      // Clean the path (remove leading/trailing slashes, 'roda/' prefix if present)
      let cleanPath = path.toString().trim();
      cleanPath = cleanPath.replace(/^\/+|\/+$/g, ''); // Remove leading/trailing slashes
      cleanPath = cleanPath.replace(/^roda\//i, ''); // Remove 'roda/' prefix if present

      // Security check: prevent path traversal
      if (cleanPath.includes('..') || cleanPath.includes('//')) {
        return new Response(JSON.stringify({ error: 'Invalid path' }), {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        });
      }

      // Get file data
      const fileBuffer = await file.arrayBuffer();

      // Upload to R2
      await env.RODA_BUCKET.put(cleanPath, fileBuffer, {
        httpMetadata: {
          contentType: file.type || 'application/octet-stream',
        },
      });

      // Construct the public URL
      const publicUrl = `https://pub-332d53d6ee8c469a9306eae69acfceb0.r2.dev/${cleanPath}`;

      // Return success response
      return new Response(
          JSON.stringify({
            success: true,
            url: publicUrl,
            path: cleanPath,
            size: fileBuffer.byteLength,
            type: file.type,
          }),
          {
            status: 200,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          }
      );

    } catch (error) {
      console.error('Upload error:', error);
      return new Response(
          JSON.stringify({
            error: 'Upload failed',
            details: error.message
          }),
          {
            status: 500,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          }
      );
    }
  },
};
