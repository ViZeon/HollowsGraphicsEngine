package vault

Texture_Source :: struct {
    pixels: [dynamic]u8,
    width:  i32,
    height: i32,
    format: Texture_Format, // RGB, RGBA, etc
}

Texture_Cache :: struct {
    // TODO: GPU handle, mips, etc
}

Texture :: struct {
    source: Texture_Source,
    cache:  Texture_Cache,
}

Texture_Format :: enum {
    RGB,
    RGBA,
    Grayscale,
    Grayscale_Alpha,
}