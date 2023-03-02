precision highp float;
varying vec2 textureCoordinate;
varying vec2 textureCoordinate2;

uniform sampler2D inputImageTexture;
uniform sampler2D inputImageTexture2;

uniform float maintime;
//uniform vec2 direction; // = vec2(0.0, 1.0)

vec4 getFromColor(vec2 uv){
    vec2 tt = vec2(uv.x,uv.y);
    return texture2D(inputImageTexture, tt);
}
vec4 getToColor(vec2 uv){
    vec2 tt = vec2(uv.x,uv.y);
    return texture2D(inputImageTexture2, tt);
 }

void main()
{
    vec4 textureColor = texture2D(inputImageTexture, textureCoordinate);
    vec4 textureColor2 = texture2D(inputImageTexture2, textureCoordinate2);
    
    vec2 p=textureCoordinate.xy/vec2(1.0).xy;
    vec4 a=getFromColor(p);
    vec4 b=getToColor(p);
    gl_FragColor = mix(a, b, step(0.0+p.x,maintime));
    
}
