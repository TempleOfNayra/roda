// R2 Cloudflare Worker for Roda App
// Handles profile pictures and group media uploads

export default {
  async fetch(request, env) {
    // CORS headers
    const corsHeaders = {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type, Authorization',
    };

    // Handle CORS preflight
    if (request.method === 'OPTIONS') {
      return new Response(null, { headers: corsHeaders });
    }

    // Check authorization
    const authHeader = request.headers.get('Authorization');
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return new Response(
        JSON.stringify({ error: 'Missing or invalid authorization' }), 
        { 
          status: 401,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      );
    }

    const token = authHeader.substring(7);
    if (token !== env.UPLOAD_API_KEY) {
      return new Response(
        JSON.stringify({ error: 'Invalid API key' }), 
        { 
          status: 401,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      );
    }

    // Handle uploads
    if (request.method === 'POST') {
      try {
        const formData = await request.formData();
        const file = formData.get('file');
        const userId = formData.get('userId');
        const type = formData.get('type') || 'general';
        const groupId = formData.get('groupId'); // For group media
        const mediaType = formData.get('mediaType'); // 'photo' or 'video'

        if (!file) {
          return new Response(
            JSON.stringify({ error: 'No file provided' }), 
            { 
              status: 400,
              headers: { ...corsHeaders, 'Content-Type': 'application/json' }
            }
          );
        }

        // Determine path based on upload type
        let path;
        const timestamp = Date.now();
        const filename = file.name || 'upload';
        
        if (type === 'profile_picture') {
          // Profile pictures go in user folder
          path = `users/${userId}/profile/${timestamp}_${filename}`;
        } else if (type === 'group_logo') {
          // Group logos
          path = `groups/${groupId || userId}/logo/${timestamp}_${filename}`;
        } else if (type === 'group_header') {
          // Group headers
          path = `groups/${groupId || userId}/header/${timestamp}_${filename}`;
        } else if (type === 'group_media') {
          // Group media (photos/videos from media tab)
          const mediaFolder = mediaType === 'video' ? 'videos' : 'photos';
          path = `groups/${groupId || userId}/media/${mediaFolder}/${timestamp}_${filename}`;
        } else {
          // Default path
          path = `uploads/${userId}/${timestamp}_${filename}`;
        }

        // Upload to R2
        const arrayBuffer = await file.arrayBuffer();
        await env.RODA_BUCKET.put(path, arrayBuffer, {
          httpMetadata: {
            contentType: file.type || 'application/octet-stream',
          },
          customMetadata: {
            uploadedBy: userId,
            uploadType: type,
            originalName: filename,
            uploadedAt: new Date().toISOString(),
            groupId: groupId || '',
            mediaType: mediaType || '',
          },
        });

        // Construct the public URL
        const publicUrl = `https://rodabucket.nyc3.cdn.digitaloceanspaces.com/${path}`;

        return new Response(
          JSON.stringify({ 
            success: true,
            url: publicUrl,
            path: path,
            type: type,
            size: arrayBuffer.byteLength,
          }), 
          { 
            status: 200,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }
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
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }
          }
        );
      }
    }

    // Handle GET requests (for fetching media lists)
    if (request.method === 'GET') {
      const url = new URL(request.url);
      const pathPrefix = url.searchParams.get('prefix');
      
      if (!pathPrefix) {
        return new Response(
          JSON.stringify({ error: 'Missing prefix parameter' }), 
          { 
            status: 400,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }
          }
        );
      }

      try {
        // List objects with prefix
        const listed = await env.RODA_BUCKET.list({
          prefix: pathPrefix,
          limit: 100,
        });

        const files = listed.objects.map(obj => ({
          key: obj.key,
          size: obj.size,
          uploaded: obj.uploaded,
          url: `https://rodabucket.nyc3.cdn.digitaloceanspaces.com/${obj.key}`,
          metadata: obj.customMetadata,
        }));

        return new Response(
          JSON.stringify({ 
            success: true,
            files: files,
            truncated: listed.truncated,
          }), 
          { 
            status: 200,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }
          }
        );

      } catch (error) {
        console.error('List error:', error);
        return new Response(
          JSON.stringify({ 
            error: 'Failed to list files',
            details: error.message 
          }), 
          { 
            status: 500,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }
          }
        );
      }
    }

    // Handle DELETE requests (for removing media)
    if (request.method === 'DELETE') {
      const url = new URL(request.url);
      const path = url.searchParams.get('path');
      
      if (!path) {
        return new Response(
          JSON.stringify({ error: 'Missing path parameter' }), 
          { 
            status: 400,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }
          }
        );
      }

      try {
        await env.RODA_BUCKET.delete(path);
        
        return new Response(
          JSON.stringify({ 
            success: true,
            deleted: path,
          }), 
          { 
            status: 200,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }
          }
        );

      } catch (error) {
        console.error('Delete error:', error);
        return new Response(
          JSON.stringify({ 
            error: 'Failed to delete file',
            details: error.message 
          }), 
          { 
            status: 500,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }
          }
        );
      }
    }

    // Method not allowed
    return new Response(
      JSON.stringify({ error: 'Method not allowed' }), 
      { 
        status: 405,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      }
    );
  },
};