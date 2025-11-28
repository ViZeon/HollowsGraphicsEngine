    // Compile compute shader
#version 430
layout(local_size_x = 16, local_size_y = 16) in;

struct Vertex {
    float x, y, z;
    int x_cell, y_cell;
};

layout(std430, binding = 0) buffer VertexBuffer {
    Vertex vertices[];
};

layout(rgba32f, binding = 0) uniform image2D outputImage;

uniform int vertex_count;
uniform float min_z;
uniform float max_z;
uniform vec2 world_min;
uniform vec2 world_max;
uniform ivec2 screen_size;

int binary_search_x(int target) {
    int left = 0;
    int right = vertex_count;
    while (left < right) {
        int mid = (left + right) / 2;
        if (vertices[mid].x_cell < target) {
            left = mid + 1;
        } else {
            right = mid;
        }
    }
    return left;
}

int binary_search_y(int start, int end, int target_x, int target_y) {
    int left = start;
    int right = end;
    while (left < right) {
        int mid = (left + right) / 2;
        if (vertices[mid].x_cell != target_x) break;
        if (vertices[mid].y_cell < target_y) {
            left = mid + 1;
        } else {
            right = mid;
        }
    }
    return left;
}

void main() {
    ivec2 pixel = ivec2(gl_GlobalInvocationID.xy);
    if (pixel.x >= screen_size.x || pixel.y >= screen_size.y) return;
    
    vec2 world_pos;
    world_pos.x = mix(world_min.x, world_max.x, float(pixel.x) / float(screen_size.x));
    world_pos.y = mix(world_min.y, world_max.y, float(pixel.y) / float(screen_size.y));
    
    int target_x = int(floor(world_pos.x));
    int target_y = int(floor(world_pos.y));
    
    int x_start = binary_search_x(target_x);
    int x_end = binary_search_x(target_x + 1);
    
    if (x_start >= vertex_count || x_start == x_end) {
        imageStore(outputImage, pixel, vec4(1.0, 0.0, 0.0, 1.0)); // Red for debug
        return;
    }
    
    int y_start = binary_search_y(x_start, x_end, target_x, target_y);
    int y_end = binary_search_y(x_start, x_end, target_x, target_y + 1);
    
    if (y_start >= x_end || y_start == y_end) {
        imageStore(outputImage, pixel, vec4(0.0, 1.0, 0.0, 1.0)); // Green for debug
        return;
    }
    
    float closest_z = 1e10;
    float total_weight = 0.0;
    float weighted_z = 0.0;
    
    for (int i = y_start; i < y_end && i < vertex_count; i++) {
        if (vertices[i].x_cell != target_x || vertices[i].y_cell != target_y) break;
        
        float dx = vertices[i].x - world_pos.x;
        float dy = vertices[i].y - world_pos.y;
        float dist = sqrt(dx*dx + dy*dy);
        
        if (dist < 1.0) {
            float weight = 1.0 / (dist + 0.01);
            weighted_z += vertices[i].z * weight;
            total_weight += weight;
        }
    }
    
    if (total_weight > 0.0) {
        float z = weighted_z / total_weight;
        float normalized = (z - min_z) / (max_z - min_z + 0.001);
        imageStore(outputImage, pixel, vec4(normalized, normalized, normalized, 1.0));
    } else {
        imageStore(outputImage, pixel, vec4(0.0, 0.0, 1.0, 1.0)); // Blue for debug
    }
}
