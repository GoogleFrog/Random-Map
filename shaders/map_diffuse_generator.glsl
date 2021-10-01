uniform sampler2D tex0; // unqualified heightfield
uniform sampler2D tex1; // 2d normals
uniform sampler2D tex2; // hard rock texture
uniform sampler2D tex3; // flats texture (tier0)
uniform sampler2D tex4; // beach texture (tier-1)
uniform sampler2D tex5; // mid-altitude flats (tier1, grassland)
uniform sampler2D tex6; // high-altitude flats (tier2)
uniform sampler2D tex7; // hillside texture
uniform sampler2D tex8; // ramp texture

uniform float minHeight;
uniform float maxHeight;

// should these be uniforms?
const float hardCliffMax = 1.0; // sharpest bot-blocking cliff
const float hardCliffMin = 0.58778525229; // least sharp bot-blocking cliff

const float softCliffMax = hardCliffMin;
const float softCliffMin = 0.30901699437;


vec2 rotate(vec2 v, float a) {
    float s = sin(a);
    float c = cos(a);
    mat2 m = mat2(c, -s, s, c);
    return m * v;
}

void main()
{
    vec2 coord = vec2(gl_TexCoord[0].s,0.5*gl_TexCoord[0].t);
    vec4 norm = texture2D(tex1, coord);
    vec2 norm2d = vec2(norm.x, norm.a);
    float slope = length(norm2d);
    float factor = 0.0;
    float height = texture2D(tex0,coord).r;

    // tile somewhat
    coord = 8.0*coord;

    // base texture
    gl_FragColor = texture2D(tex2,coord);

    // ---- altitude textures ----

    // admix depths (actually same as beaches atm)
    factor = smoothstep(-5.0,-17.0,height);
    gl_FragColor = mix(gl_FragColor,texture2D(tex4,coord*8.0),factor);

    // admix beaches
    factor = clamp(0.1*(10.0-abs(height)),0.0,1.0);
    gl_FragColor = mix(gl_FragColor,texture2D(tex4,coord*8.0),factor);

    // admix midlands
    factor = smoothstep(50.0,150.0,height) * (1.0-slope);
    gl_FragColor = mix(gl_FragColor,texture2D(tex5,coord*3.0),factor);

    // admix highlands
    factor = smoothstep(200.0,300.0,height);
    gl_FragColor = mix(gl_FragColor,texture2D(tex6,coord),factor);

    // ---- slope textures ----

    // admix ramps
    factor = 0.25*smoothstep(0.1, softCliffMin, slope);
    gl_FragColor = mix(gl_FragColor,texture2D(tex8,coord*2.0),factor);

    // admix hillsides (replace texture later)
    factor = 0.5*smoothstep(softCliffMin, softCliffMax, slope);
    gl_FragColor = mix(gl_FragColor,texture2D(tex7,coord*2.0),factor);

    // admix cliffsides
    factor = smoothstep(hardCliffMin, hardCliffMax, slope);
    gl_FragColor = mix(gl_FragColor,texture2D(tex3,coord),factor);
}