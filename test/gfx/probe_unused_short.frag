// With probe_unused_long.frag (run_tests.py): globals a shader never uses,
// a const and a variable, leave nothing in its SPIR-V, not even their
// names, so the two compile to SPIR-V of one size. A Vulkan driver has
// crashed on a pipeline whose two stages each declared such a global.
const float E = 0.25e-6;
float g = 2.0;
layout(location = 0) out vec4 result;
void main() { result = vec4(0.5); }
