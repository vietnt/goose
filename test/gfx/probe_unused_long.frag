// probe_unused_short.frag, with longer names for its unused globals.
const float WATER_EPSILON_IN_DEPTH_UNITS = 0.25e-6;
float global_scale_that_nothing_reads = 2.0;
layout(location = 0) out vec4 result;
void main() { result = vec4(0.5); }
