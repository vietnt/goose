// Storage buffers at their std430 offsets on every backend: structs with a
// vec3 inside, arrays of them and of vec3s (each 16 bytes), written whole, in
// part, through a swizzle and a component index, by compound assignment and
// ++, through atomics, and read back from an element other than the first,
// in a compute shader and in a fragment shader. Padding is never written.
import std;
import os;
import gfx;

// The shaders' struct P, laid out as std430 lays it out.
struct P { a: f32, pad 12, x: f32, y: f32, z: f32, pad 4, u: f32, v: f32, id: u32, k: i32 }

fn open_or_skip() -> bool {
    if gfx::open_headless(4, 1) { return true; }
    write_stderr(str("gfx: ", gfx::error(), "\n"));
    return false;
}

fn main() {
    guard open_or_skip() else { return; }

    // Five elements of P and six vec3s, so that each length() tells its stride.
    var ps: P[>..] = [];
    for i in 5 {
        ps.push(P { a: 10 + i, x: i, y: i + 0.5, z: -i, u: 2 * i, v: 3 * i,
                    id: (100 + i) as u32, k: -i as i32 });
    }
    // Each vec3 has a fourth float, which is padding and must never be read.
    var v3s: f32[>..] = [];
    for i in 6 { v3s.append([10 * i + 1, 10 * i + 2, 10 * i + 3, 999.0]); }
    let ints: i32[4] = [0, 5, 2, -1];
    var marked: u8[>..] = [];
    marked.resize(4 * 48, 0xAB);
    let input = gfx::buffer(gfx::BUFFER_COMPUTE_READ | gfx::BUFFER_STORAGE, bytes_of(ps));
    let vec3s = gfx::buffer(gfx::BUFFER_COMPUTE_READ, bytes_of(v3s));
    let output = gfx::buffer(gfx::BUFFER_COMPUTE_WRITE, marked.len, marked);
    let counts = gfx::buffer(gfx::BUFFER_COMPUTE_WRITE, 16, "");
    let signed = gfx::buffer(gfx::BUFFER_COMPUTE_WRITE, bytes_of(ints));

    let shader = embed_shader("comp", """
        layout(local_size_x = 4) in;
        struct P { float a; vec3 v; vec2 uv; uint id; int k; };
        layout(std430, set = 0, binding = 0) readonly buffer In { P ps[]; };
        layout(std430, set = 0, binding = 1) readonly buffer In3 { vec3 v3s[]; };
        layout(std430, set = 1, binding = 0) buffer Out { P qs[]; };
        layout(std430, set = 1, binding = 1) buffer Counts { uint n[]; } counts;
        layout(std430, set = 1, binding = 2) buffer Ints { int is[]; };
        void main() {
            uint i = gl_GlobalInvocationID.x;
            qs[i] = ps[3u - i];
            qs[i].v.y += 1.0;
            qs[i].v[int(i) % 1 + 2] = v3s[i].z;
            qs[i].uv = v3s[i].xy * 0.5;
            qs[i].uv.y *= 2.0;
            qs[i].id++;
            ++qs[i].k;
            qs[i].a = float(ps.length()) + 10.0 * float(v3s.length());
            atomicAdd(counts.n[1], i + 1u);
            atomicCompSwap(counts.n[2], 0u, 5u);
            atomicCompSwap(counts.n[2], 7u, 9u);
            atomicMax(is[1], -3);
            atomicMin(is[2], -3);
            if (i == 2u) atomicExchange(is[3], 7);
            if (i == 3u) counts.n[3] = uint(counts.n.length());
        }
        """);
    let rw: gfx::Buffer[3] = [output, counts, signed];
    gfx::begin_compute(rw);
    gfx::bind(gfx::compute_pipeline(shader));
    gfx::bind_storage_buffer(gfx::COMPUTE, 0, input);
    gfx::bind_storage_buffer(gfx::COMPUTE, 1, vec3s);
    gfx::dispatch(1, 1, 1);
    gfx::end_compute();

    var qs: P[>..] = [];
    gfx::read_buffer(output, qs, 4);
    for i in 4 {
        let q = qs[i];
        print("qs[", i, "]: a ", q.a, ", v ", q.x, " ", q.y, " ", q.z, ", uv ", q.u, " ", q.v,
              ", id ", q.id, ", k ", q.k);
    }
    // Bytes 4 to 15 and 28 to 31 of each element are padding.
    var raw: u8[>..] = [];
    raw.resize(4 * 48, 0);
    gfx::read_buffer(output, 0, raw);
    var kept = true;
    for i in 4 {
        for b in 48 {
            if ((b >= 4 && b < 16) || (b >= 28 && b < 32)) && raw[i * 48 + b] != 0xAB { kept = false; }
        }
    }
    print("padding untouched: ", kept);
    var ns: u32[>..] = [];
    gfx::read_buffer(counts, ns, 4);
    print("counts: ", ns);
    var is: i32[>..] = [];
    gfx::read_buffer(signed, is, 4);
    print("signed atomics: ", is);

    // A fragment shader reads element x of the same buffer for pixel x.
    let fs = embed_shader("frag", """
        struct P { float a; vec3 v; vec2 uv; uint id; int k; };
        layout(std430, set = 2, binding = 0) readonly buffer In { P ps[]; };
        layout(location = 0) out vec4 color;
        void main() {
            P p = ps[int(gl_FragCoord.x)];
            color = vec4(float(p.id), p.v.y * 2.0, float(p.k + 10), p.uv.y) / 255.0;
        }
        """);
    let vs = embed_shader("vert", """
        void main() {
            vec2 p = vec2(float((gl_VertexIndex << 1) & 2), float(gl_VertexIndex & 2));
            gl_Position = vec4(p * 2.0 - 1.0, 0.0, 1.0);
        }
        """);
    let target = gfx::render_target(4, 1, gfx::RGBA8);
    gfx::begin_pass(target, gfx::Texture { 0 }, float4 { 0.0, 0.0, 0.0, 0.0 });
    gfx::bind(gfx::pipeline(vs, fs));
    gfx::bind_storage_buffer(gfx::FRAGMENT, 0, input);
    gfx::draw(3);
    gfx::end_pass();
    let px = gfx::read_pixels(target);
    var line: u8[>..] = [];
    for x in 4 {
        format(line, if x > 0 { "  " } else { "" }, px[x * 4], ",", px[x * 4 + 1], ",", px[x * 4 + 2], ",", px[x * 4 + 3]);
    }
    print("fragment reads: ", line);
    gfx::close();
}
