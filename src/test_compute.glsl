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

        if (axis == 3) {
        return vertices[index].x_cell;
    }
        if (axis == 4) {
        return vertices[index].y_cell;
    }
    return 0;
}

// Returns index of value, or -1 if not found
// ONLY THIS FUNCTION IS FIXED — everything else in your shader stays exactly the same

ivec2 scan_verts(int axis, float min_value, float max_value, int first_cell, int last_cell) 
{
    int start = -1;
    int end   = -1;

    // ─── LOWER BOUND: first index where vertices[index] >= min_value ───
    {
        int left  = first_cell;
        int right = last_cell;
        while (left <= right) {
            int mid = (left + right) / 2;
            if (get_vert_value(mid, axis) >= min_value) {
                start = mid;
                right = mid - 1;    // look for even smaller index on the left
            } else {
                left = mid + 1;
            }
        }
    }

    // ─── UPPER BOUND: first index where vertices[index] > max_value ───
    if (start != -1) {
        int left  = start;
        int right = last_cell;
        while (left <= right) {
            int mid = (left + right) / 2;
            if (get_vert_value(mid, axis) <= max_value) {
                end = mid;
                left = mid + 1;     // look for even larger index on the right
            } else {
                right = mid - 1;
            }
        }
    }

    if (start == -1) return ivec2(-1, -1);
    return ivec2(start, end);   // inclusive range [start, end]
}

/*
int find_closest_index(float target, ivec2 range) {
    int left = range.x;
    int right = range.y;
    
    while (left < right) {
        int mid = (left + right) / 2;
        
        if (vertices[mid].x < target) {
            left = mid + 1;
        } else {
            right = mid;
        }
    }
    
    return left;  // Returns index of closest value >= target
}
*/
layout(std430, binding = 1) buffer DebugBuffer {
    ivec2 debug_value[];
};


void main() {
    ivec2 pixel = ivec2(gl_GlobalInvocationID.xy);
    if (pixel.x >= screen_size.x || pixel.y >= screen_size.y) return;
    

    vec2 pixel_size = vec2(
    (world_max.x - world_min.x) / float(screen_size.x),
    (world_max.y - world_min.y) / float(screen_size.y)
    );
    
    vec2 world_pos = vec2(
        world_min.x + (float(pixel.x) / float(screen_size.x)) * (world_max.x - world_min.x),
        world_min.y + (float(pixel.y) / float(screen_size.y)) * (world_max.y - world_min.y)
    );
    


    float depth_range = min_z + (max_z - min_z);


    // Binary search Usage:
    ivec2 range_x;
    ivec2 range_y;
    ivec2 range_z;

    float culling_range = 10000;
    float pixel_range = 10;

    range_x = scan_verts (3, world_pos.x - (pixel_size.x * pixel_range), world_pos.x + (pixel_size.x * pixel_range), 0, vertex_count - 1);
    range_y = scan_verts (4, world_pos.y - (pixel_size.y * pixel_range), world_pos.y + (pixel_size.y * pixel_range), range_x.x, range_x.y);
    range_z = scan_verts (2, 0, culling_range, range_y.x, range_y.y);


    int index = pixel.y * screen_size.x + pixel.x;

    float depth = vertices [range_z.x].z  - depth_range ;

    float depth_normalized = (vertices[range_z.y].z - min_z) / (max_z - min_z);

    //if (world_pos)

    //if (world_pos)

    //garbage for testing and disposal
    // Each pixel gets a different color based on position
    float r = range_y.x;//world_min.x; //float(pixel.x) / float(screen_size.x);  // 0.0 to 1.0 left to right
    float g = range_y.y;//float(pixel.y) / float(screen_size.y);  // 0.0 to 1.0 top to bottom
        
    float grayscale = depth_normalized;

    debug_value[index] = range_x;

    imageStore(outputImage, pixel, vec4(r, g, 0.5, 1.0));
    imageStore(outputImage, pixel, vec4(grayscale, grayscale, grayscale, 1.0));
    //imageStore(outputImage, pixel, vec4(1.0, 0.0, 0.0, 1.0)); // Solid Red

}