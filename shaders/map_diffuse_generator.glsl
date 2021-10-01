uniform sampler2D tex0; // unqualified heightfield
uniform sampler2D tex1; // 2d normals
uniform sampler2D tex2; // hard rock texture
uniform sampler2D tex3; // flats texture (tier0)
uniform sampler2D tex4; // beach texture (tier-1)
uniform sampler2D tex5; // mid-altitude flats (tier1, grassland)
uniform sampler2D tex6; // high-altitude flats (tier2)
uniform sampler2D tex7; // hillside texture
uniform sampler2D tex8; // ramp texture
uniform sampler2D tex9; // cloud grass
uniform sampler2D tex10; // cloud grassdark
uniform sampler2D tex11; // cloud san

uniform float minHeight;
uniform float maxHeight;

// should these be uniforms?
const float hardCliffMax = 1.0; // sharpest bot-blocking cliff
const float hardCliffMin = 0.58778525229; // least sharp bot-blocking cliff

const float vehCliff = 0.4546;
const float botCliff = 0.8065;

const float softCliffMax = hardCliffMin;
const float bandingMin = 0.16;
const float vehCliffMinus = 0.24;
const float vehCliffEpsilon = 0.492;
const float vehCliffPlus = 0.62;
const float botCliffMinus = botCliff - 0.02;


vec2 rotate(vec2 v, float a) {
    float s = sin(a);
    float c = cos(a);
    mat2 m = mat2(c, -s, s, c);
    return m * v;
}

void main()
{
    vec2 coord = vec2(gl_TexCoord[0].s,gl_TexCoord[0].t);
    vec4 norm = texture2D(tex1, coord);
    vec2 norm2d = vec2(norm.x, norm.a);
    float slope = length(norm2d);
    float factor = 0.0;
    float height = texture2D(tex0,coord).r;

    // tile somewhat
    coord = 8.0*coord;

    // base texture
    gl_FragColor = texture2D(tex11,coord*min(1.2, 1.1 + 0.1*slope));

    // ---- altitude textures ----

    // admix depths (actually same as beaches atm)
    factor = smoothstep(-5.0,-17.0,height);
    gl_FragColor = mix(gl_FragColor,texture2D(tex3,coord*1.0),factor);

    // admix beaches
    //factor = clamp(0.1*(10.0-abs(height)),0.0,1.0);
    //gl_FragColor = mix(gl_FragColor,texture2D(tex2,coord*8.0),factor);

    // admix cracks
    factor = smoothstep(70.0,95.0,height) * (1.0-slope);
    gl_FragColor = mix(gl_FragColor,texture2D(tex2,coord*min(1.3, 1.15 + 0.005*slope)),factor);

    // admix low grass
    factor = smoothstep(115.0,135.0,height) * (1.0-slope);
    gl_FragColor = mix(gl_FragColor,texture2D(tex10,coord*min(1.05, 1.0 + 1.0*slope)),factor);
	
    // admix high grass
    factor = smoothstep(170.0,190.0,height);
    gl_FragColor = mix(gl_FragColor,texture2D(tex9,coord*min(1.05, 0.8 + 0.2*slope)),factor);

    // admix highlands
    factor = smoothstep(255.0,290.0,height);
    gl_FragColor = mix(gl_FragColor,texture2D(tex6,coord*min(0.82, 0.8 + 0.001*slope)),factor);

    // ---- slope textures ----

    // admix ramps
	if (slope < vehCliff) {
		if (slope > bandingMin) {
			factor = 0.6*smoothstep(bandingMin, vehCliff, slope)*(1.0 - (1.0 - smoothstep(vehCliffMinus, vehCliffPlus, slope))*(sin(height/1.6) + 1.0)*0.5);
			gl_FragColor = mix(gl_FragColor,texture2D(tex2,coord*3.0), 0.7*smoothstep(bandingMin, vehCliff, slope));
			gl_FragColor = mix(gl_FragColor,texture2D(tex8,coord*2.0), factor);
		}
	}
	else if (slope < vehCliffEpsilon) {
		factor = 0.6*(1.0 - (1.0 - smoothstep(vehCliffMinus, vehCliffPlus, vehCliff))*(sin(height/1.6) + 1.0)*0.5);
		factor = factor*(vehCliffEpsilon - slope)/(vehCliffEpsilon - vehCliff) + (1.0 - (vehCliffEpsilon - slope)/(vehCliffEpsilon - vehCliff));
		gl_FragColor = mix(gl_FragColor,texture2D(tex2,coord*3.0), 0.7);
		gl_FragColor = mix(gl_FragColor,texture2D(tex8,coord*2.0), 0.8);
	}
	else if (slope < botCliff) {
		gl_FragColor = mix(gl_FragColor,texture2D(tex2,coord*3.0), 0.7);
		gl_FragColor = mix(gl_FragColor,texture2D(tex8,coord*2.0), 1.0 + 0.2*smoothstep(vehCliffEpsilon, botCliff, slope));
		if (slope > botCliffMinus) {
			factor = smoothstep(botCliffMinus, botCliff, slope);
			gl_FragColor = mix(gl_FragColor,texture2D(tex3,0.9*coord),factor);
			gl_FragColor = mix(gl_FragColor,texture2D(tex7,0.7*coord*slope*0.1),factor*0.2);
		}
	}
	else {
		// admix cliffsides
		gl_FragColor = mix(gl_FragColor,texture2D(tex3,0.9*coord),1.0);
		gl_FragColor = mix(gl_FragColor,texture2D(tex7,0.7*coord*slope*0.1),0.2);
	}
	
	// Show mountains over cliffs
	if (height > 255.0) {
		factor = smoothstep(255.0,290.0,height)*(1.0 - slope)*0.7 + 0.3;
		gl_FragColor = mix(gl_FragColor,texture2D(tex6,coord*min(0.82, 0.8 + 0.001*slope)),factor);
	}
}