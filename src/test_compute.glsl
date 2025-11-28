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
    
    // Test: visualize first vertex's x_cell
    if (vertex_count > 0) {
        float val = float(vertices[0].x_cell) / 100.0;
        imageStore(outputImage, pixel, vec4(val, val, val, 1.0));
    }
}