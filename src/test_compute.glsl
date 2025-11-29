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


/*
// Returns index of value, or -1 if not found
int scan_verts(int axis, float min_value, float max_value, int first_cell, int last_cell, out int start, out int end) {
    start = -1;
    end = -1;
    
    // Find start (first >= min_value)
    int left = first_cell;
    int right = last_cell;

    //

    while (left <= right) {
        int mid = (left + right) / 2;
        
        if (start > -1) {
            if (vertices[mid].v[axis] <= max_value) {
                end = mid;
                left = mid + 1;
            } else {
                right = mid - 1;
            }
        }
        else {
            if (vertices[mid].v[axis] >= min_value) {
                start = mid;
                right = mid - 1;
            } else {
                left = mid + 1;
            }
        }


    }
    
    if (start == -1) return;  // No values >= min_value
    
    /*
    // Find end (last <= max_value)
    left = start;  // Start from where we found the first match
    right = vertex_count - 1;
    
    while (left <= right) {
        int mid = (left + right) / 2;
        
        if (vertices[mid].x <= max_value) {
            end = mid;
            left = mid + 1;
        } else {
            right = mid - 1;
        }
    }
    */
//}


void main() {
    ivec2 pixel = ivec2(gl_GlobalInvocationID.xy);
    if (pixel.x >= screen_size.x || pixel.y >= screen_size.y) return;
    
    
    vec2 world_pos = vec2(
        world_min.x + (float(pixel.x) / float(screen_size.x)) * (world_max.x - world_min.x),
        world_min.y + (float(pixel.y) / float(screen_size.y)) * (world_max.y - world_min.y)
    );
    

    // Binary search Usage:
    //int start, end;

    //scan_verts (0, world_pos, world_pos+1, 0, vertex_count - 1, start, end);



    //find_range(0, int(world_pos), int(world_pos) +1, start, end);
    
    /*
    if (start != -1 && end != -1) {
        for (int i = start; i <= end; i++) {
            // Process vertices[i]
        }
    }
    */



    //if (world_pos)

    //garbage for testing and disposal
    // Each pixel gets a different color based on position
    float r = world_min.x; //float(pixel.x) / float(screen_size.x);  // 0.0 to 1.0 left to right
    float g = world_min.y;//float(pixel.y) / float(screen_size.y);  // 0.0 to 1.0 top to bottom
    
    imageStore(outputImage, pixel, vec4(r, g, 0.5, 1.0));
    //imageStore(outputImage, pixel, vec4(1.0, 0.0, 0.0, 1.0)); // Solid Red

}