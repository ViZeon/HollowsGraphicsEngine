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

layout(rgba8, binding = 0) uniform image2D outputImage;

uniform int vertex_count;
uniform ivec2 screen_size;
uniform vec2 world_min;
uniform vec2 world_max;
uniform float min_z;
uniform float max_z;



float get_vert_value (int index, int axis) {
    if (axis == 0) {
        return vertices[index].x;
    }
        if (axis == 1) {
        return vertices[index].y;
    }
        if (axis == 2) {
        return vertices[index].z;
    }
    return 0;
}

// Returns index of value, or -1 if not found
vec2 scan_verts(int axis, float min_value, float max_value, int first_cell, int last_cell) {
    int start = -1;
    int end = -1;
    
    // Find start (first >= min_value)
    int left = first_cell;
    int right = last_cell;

    //


    while (left <= right) {
        int mid = (left + right) / 2;
        
        if (start > -1) {
            if (get_vert_value(mid,axis) <= max_value) {
                end = mid;
                left = mid + 1;
            } else {
                right = mid - 1;
            }
        }
        else {
            if (get_vert_value(mid,axis) >= min_value) {
                start = mid;
                right = mid - 1;
            } else {
                left = mid + 1;
            }
        }


    }
    
    if (start == -1) {return vec2(start,end); }
    return vec2(start,end);  // No values >= min_value
}


void main() {
    ivec2 pixel = ivec2(gl_GlobalInvocationID.xy);
    if (pixel.x >= screen_size.x || pixel.y >= screen_size.y) return;
    
    
    vec2 world_pos = vec2(
        world_min.x + (float(pixel.x) / float(screen_size.x)) * (world_max.x - world_min.x),
        world_min.y + (float(pixel.y) / float(screen_size.y)) * (world_max.y - world_min.y)
    );
    

    // Binary search Usage:
    vec2 range;

    range = scan_verts (0, world_pos.x, world_pos.x + 1, 0, vertex_count - 1);




    //if (world_pos)

    //garbage for testing and disposal
    // Each pixel gets a different color based on position
    //float r = range.x;//world_min.x; //float(pixel.x) / float(screen_size.x);  // 0.0 to 1.0 left to right
    //float g = range.y;//float(pixel.y) / float(screen_size.y);  // 0.0 to 1.0 top to bottom
    
    float grayscale = range.y/10000;

    //imageStore(outputImage, pixel, vec4(r, g, 0.5, 1.0));
    imageStore(outputImage, pixel, vec4(grayscale, grayscale, grayscale, 1.0));
    //imageStore(outputImage, pixel, vec4(1.0, 0.0, 0.0, 1.0)); // Solid Red

}