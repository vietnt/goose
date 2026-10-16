// textureGather returns one component of the four texels around P, in
// GLSL's order: (i0, j1), (i1, j1), (i1, j0), (i0, j0). Of a 2 x 2 texture
// whose red is 10 20 on row 0 and 30 40 on row 1, green red + 1 and blue
// red + 2, gathering at its center reads 30 40 20 10 from red. Layer 1 of an
// array holds the same plus 100.
import std;
import os;
import gfx;

fn texels(px: u8[:]) -> u8[>..] { str(px[0], ",", px[1], ",", px[2], ",", px[3]) }

fn main() {
    if !gfx::open_headless(1, 1) {
        write_stderr(str("gfx: ", gfx::error(), "\n"));
        return;
    }
    let vs = embed_shader("vert", """
        void main() {
            vec2 p = vec2(float((gl_VertexIndex << 1) & 2), float(gl_VertexIndex & 2));
            gl_Position = vec4(p * 2.0 - 1.0, 0.0, 1.0);
        }
        """);
    var texels_2x2: u8[16] = [0; 16];
    var layered: u8[32] = [0; 32];
    for i in 4 {
        let red = (10 * (i + 1)) as u8;
        for c in 3 { texels_2x2[i * 4 + c] = red + c as u8; }
        texels_2x2[i * 4 + 3] = 255;
        for c in 4 { layered[i * 4 + c] = texels_2x2[i * 4 + c]; }
        for c in 3 { layered[16 + i * 4 + c] = texels_2x2[i * 4 + c] + 100; }
        layered[16 + i * 4 + 3] = 255;
    }
    let flat = gfx::texture2d(2, 2);
    gfx::update_texture(flat, texels_2x2);
    let array = gfx::texture(gfx::TextureDesc { kind: gfx::TEXTURE_2D_ARRAY, width: 2, height: 2, depth: 2 });
    for l in 2 { gfx::update_texture(array, gfx::Region { layer: l as i32 }, layered[l * 16 .. l * 16 + 16]); }
    let nearest = gfx::sampler(gfx::NEAREST, gfx::CLAMP);
    let out = gfx::render_target(1, 1, gfx::RGBA8);

    let red = gfx::pipeline(vs, embed_shader("frag", """
        layout(set = 2, binding = 0) uniform sampler2D tex;
        layout(location = 0) out vec4 result;
        void main() { result = textureGather(tex, vec2(0.5)); }
        """));
    let green = gfx::pipeline(vs, embed_shader("frag", """
        layout(set = 2, binding = 0) uniform sampler2D tex;
        layout(location = 0) out vec4 result;
        void main() { result = textureGather(tex, vec2(0.5), 1); }
        """));
    let blue_layer_1 = gfx::pipeline(vs, embed_shader("frag", """
        layout(set = 2, binding = 0) uniform sampler2DArray tex;
        layout(location = 0) out vec4 result;
        void main() { result = textureGather(tex, vec3(0.5, 0.5, 1.0), 2); }
        """));
    for k in 3 {
        gfx::begin_pass(out, gfx::Texture { 0 }, float4 { 0.0, 0.0, 0.0, 0.0 });
        gfx::bind(if k == 0 { red } else if k == 1 { green } else { blue_layer_1 });
        gfx::bind_texture(gfx::FRAGMENT, 0, if k == 2 { array } else { flat }, nearest);
        gfx::draw(3);
        gfx::end_pass();
        let what = if k == 0 { "red" } else if k == 1 { "green" } else { "blue of layer 1" };
        print(what, ": ", texels(gfx::read_pixels(out)));
    }
    gfx::close();
}
