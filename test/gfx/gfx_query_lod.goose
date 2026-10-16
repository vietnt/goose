// textureQueryLod: a 64 x 64 texture drawn over 16 x 8 pixels is minified
// 4 times across and 8 times down, so sampling it uses level 3, the larger
// of the two (log2 8). With only 2 levels, the level used is clamped to 1
// while the level of detail stays 3.
import std;
import os;
import gfx;

fn main() {
    if !gfx::open_headless(16, 8) {
        write_stderr(str("gfx: ", gfx::error(), "\n"));
        return;
    }
    let vs = embed_shader("vert", """
        void main() {
            vec2 p = vec2(float((gl_VertexIndex << 1) & 2), float(gl_VertexIndex & 2));
            gl_Position = vec4(p * 2.0 - 1.0, 0.0, 1.0);
        }
        """);
    let query = gfx::pipeline(vs, embed_shader("frag", """
        layout(set = 2, binding = 0) uniform sampler2D tex;
        layout(location = 0) out vec2 lod;
        void main() { lod = textureQueryLod(tex, gl_FragCoord.xy / vec2(16.0, 8.0)); }
        """));
    let out = gfx::render_target(16, 8, gfx::RG32F);
    let linear = gfx::sampler(gfx::LINEAR, gfx::CLAMP);
    for levels in [0, 2] {
        let tex = gfx::texture(gfx::TextureDesc { width: 64, height: 64, mips: levels as i32 });
        gfx::begin_pass(out, gfx::Texture { 0 }, float4 { -1.0, -1.0, 0.0, 0.0 });
        gfx::bind(query);
        gfx::bind_texture(gfx::FRAGMENT, 0, tex, linear);
        gfx::draw(3);
        gfx::end_pass();
        var lod: f32[>..] = [];
        gfx::read_texture(out, lod);
        var same = true;
        for i in 16 * 8 { same = same && lod[i * 2] == lod[0] && lod[i * 2 + 1] == lod[1]; }
        print(if levels == 0 { 7 } else { levels }, " levels: level used ", lod[0], ", level of detail ", lod[1],
              ", at every pixel ", same);
    }
    gfx::close();
}
