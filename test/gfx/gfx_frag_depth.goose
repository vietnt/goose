// gl_FragDepth replaces the depth a fragment gets from its position: a
// triangle at depth 0.9 writes x / 8 at each pixel instead, read back exactly
// from a 32-bit float depth target by drawing it into an R32F one.
import std;
import os;
import gfx;

fn main() {
    if !gfx::open_headless(4, 1) {
        write_stderr(str("gfx: ", gfx::error(), "\n"));
        return;
    }
    let vs = embed_shader("vert", """
        void main() {
            vec2 p = vec2(float((gl_VertexIndex << 1) & 2), float(gl_VertexIndex & 2));
            gl_Position = vec4(p * 2.0 - 1.0, 0.9, 1.0);
        }
        """);
    let write_depth = gfx::pipeline(vs, embed_shader("frag", """
        layout(location = 0) out vec4 color;
        void main() {
            color = vec4(1.0);
            gl_FragDepth = gl_FragCoord.x / 8.0;
        }
        """), gfx::PipelineDesc { depth_test: true, depth_write: true });
    let color = gfx::render_target(4, 1, gfx::RGBA8);
    let depth = gfx::texture2d(4, 1, gfx::DEPTH32F, gfx::DEPTH_TARGET | gfx::SAMPLED);
    gfx::begin_pass(color, depth, float4 { 0.0, 0.0, 0.0, 1.0 });
    gfx::bind(write_depth);
    gfx::draw(3);
    gfx::end_pass();

    let copy = gfx::pipeline(vs, embed_shader("frag", """
        layout(set = 2, binding = 0) uniform sampler2D depth;
        layout(location = 0) out float result;
        void main() { result = texelFetch(depth, ivec2(gl_FragCoord.xy), 0).r; }
        """));
    let values = gfx::render_target(4, 1, gfx::R32F);
    gfx::begin_pass(values, gfx::Texture { 0 }, float4 { 0.0, 0.0, 0.0, 0.0 });
    gfx::bind(copy);
    gfx::bind_texture(gfx::FRAGMENT, 0, depth, gfx::sampler(gfx::NEAREST, gfx::CLAMP));
    gfx::draw(3);
    gfx::end_pass();
    var z: f32[>..] = [];
    gfx::read_texture(values, z);
    print("depth written: ", z[0], " ", z[1], " ", z[2], " ", z[3]);
    gfx::close();
}
