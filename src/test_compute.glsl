#version 430
layout(local_size_x = 16, local_size_y = 16) in;

struct Vertex {
    float x, y, z;
    int x_cell, y_cell;
    int _pad;
};

layout(std430, binding = 0) buffer VertexBuffer {
    Vertex vertices[];
};

layout(rgba32f, binding = 0) uniform image2D outputImage;

uniform int vertex_count;
uniform ivec2 screen_size;

void main() {
    ivec2 pixel = ivec2(gl_GlobalInvocationID.xy);
    if (pixel.x >= screen_size.x || pixel.y >= screen_size.y) return;
    
    vec4 color = vec4(0.0, 0.0, 0.1, 1.0);  // Dark blue background
    
    if (vertex_count > 0) {
        // Find min/max bounds of all vertices
        float min_x = vertices[0].x, max_x = vertices[0].x;
        float min_y = vertices[0].y, max_y = vertices[0].y;
        
        for (int i = 1; i < vertex_count; i++) {
            min_x = min(min_x, vertices[i].x);
            max_x = max(max_x, vertices[i].x);
            min_y = min(min_y, vertices[i].y);
            max_y = max(max_y, vertices[i].y);
        }
        
        // Add padding (10% margin)
        float range_x = max_x - min_x;
        float range_y = max_y - min_y;
        min_x -= range_x * 0.1;
        max_x += range_x * 0.1;
        min_y -= range_y * 0.1;
        max_y += range_y * 0.1;
        
        // Draw each vertex
        for (int i = 0; i < vertex_count; i++) {
            // Normalize vertex position to 0-1
            vec2 norm = vec2(
                (vertices[i].x - min_x) / (max_x - min_x),
                (vertices[i].y - min_y) / (max_y - min_y)
            );
            
            // Map to screen coordinates
            ivec2 v_pixel = ivec2(norm * vec2(screen_size));
            
            // Draw point with some thickness
            int dist = abs(pixel.x - v_pixel.x) + abs(pixel.y - v_pixel.y);
            if (dist <= 2) {  // 2 pixel radius
                color = vec4(1.0, 0.3, 0.3, 1.0);  // Red-orange point
            }
        }
    }
    
    imageStore(outputImage, pixel, color);
}