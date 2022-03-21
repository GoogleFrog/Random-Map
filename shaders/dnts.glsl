uniform sampler2D tex0; // unqualified heightfield
uniform sampler2D tex1; // 2d normals

uniform float minHeight;
uniform float maxHeight;

// should these be uniforms?
const float hardCliffMax = 1.0; // sharpest bot-blocking cliff
const float hardCliffMin = 0.58778525229; // least sharp bot-blocking cliff

const float vehCliff = 0.4546;
const float botCliff = 0.8065;

const float softCliffMax = hardCliffMin;
const float bandingMin = 0.12;
const float vehCliffMinus = 0.24;
const float vehCliffEpsilon = 0.492;
const float vehCliffPlus = 0.62;
const float botCliffMinus = botCliff - 0.06;
const float botCliffMinusMinus = 0.65;

vec2 rotate(vec2 v, float a) {
    float s = sin(a);
    float c = cos(a);
    mat2 m = mat2(c, -s, s, c);
    return m * v;
}

float rand(vec2 co){
    return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453);
}

void main()
{
    vec2 coord = vec2(gl_TexCoord[0].s,gl_TexCoord[0].t);
    vec4 norm = texture2D(tex1, coord);
    vec2 norm2d = vec2(norm.x, norm.a);
    float slope = length(norm2d);
    float factor = 0.0;
    float height = texture2D(tex0,coord).r;
	float factorRand = rand(coord);

    // tile somewhat
    coord = 8.0*coord;

    // base texture
    // base texture
    gl_FragColor = vec4(0,0,0,0);
    // ---- altitude textures ----
	gl_FragColor = vec4(0,0.0,0, 0.0);
	if (height > 300.0) {
		factor = 1.0-smoothstep(255.0, 330.0, height);
		gl_FragColor = mix(gl_FragColor,vec4(1.0,0,0.0,0.0), factor);
		factor = smoothstep(300.0,360.0,height);
		gl_FragColor = mix(gl_FragColor,vec4(0,0,0.0,0.4), 0.4);	
	}
	else if (height > 120.0){
		if (height > 255.0) {
			factor = 1.0-smoothstep(255.0, 330.0, height);
			gl_FragColor = mix(gl_FragColor,vec4(1.0,0,0,0.0), factor);
		}
		else if (height > 150.0) {
			gl_FragColor = mix(gl_FragColor,vec4(1.0,0,0,0.0), factorRand);
		}
		else {
			factor = smoothstep(120.0,150.0, height);		
			gl_FragColor = mix(gl_FragColor,vec4(1.0,0,0,0.0), factor);
		}
	}
	else {
		if (factorRand > 0.99) {
			gl_FragColor = vec4(0,0.0,0, 0.2);
		}
		else {
			gl_FragColor = mix(gl_FragColor,vec4(0,0,1.0,0.0), factorRand);
		}		
	}
    // admix highlands
	if (slope > botCliff-0.00001){
		gl_FragColor = vec4(0,0,0, 0.0);
		factor = 0.6+0.2*(smoothstep(botCliffMinusMinus, 1.0, slope));
		gl_FragColor = mix(gl_FragColor,vec4(0,1.0,0,0.0), factor);
	}
	else if (slope < vehCliff) {
		if (slope > bandingMin) {
			factor = 0.5*smoothstep(bandingMin, vehCliff, slope)*(1.0 - (1.0 - smoothstep(vehCliffMinus, vehCliffPlus, slope))*(sin(height/1.6) + 1.0)*0.5);
			gl_FragColor = mix(gl_FragColor,vec4(0,0,0,1.0),factor);
		}
	}
	else if (slope < vehCliffEpsilon) {
		factor = 0.6+0.4*smoothstep(vehCliffEpsilon, botCliff, slope);
		gl_FragColor = mix(gl_FragColor,vec4(0,0,0,1.0),factor);
	}
	else if (slope < botCliff) {
		factor = 0.8+0.2*smoothstep(vehCliffEpsilon, botCliff, slope);
		gl_FragColor = mix(gl_FragColor,vec4(0,0,0,1.0),factor);
	}
}
