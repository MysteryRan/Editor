precision highp float;
varying highp vec2 textureCoordinate;
uniform sampler2D inputImageTexture;
uniform float iTime;

void main() {
    float offsetx = textureCoordinate.x;
    float offsety = textureCoordinate.y;

    offsetx = sin(mod(textureCoordinate.y * 1.0 * 2.0, 2.0) * 3.14159) * 0.1;
    offsetx = (textureCoordinate.x) + offsetx * sin(iTime);
    
    if (offsetx < 0.0) {
        offsetx = -offsetx;
    } else if(offsetx > 1.0){
        offsetx = 2.0 - offsetx;
    }
    
    vec2 uv = vec2(offsetx, offsety);

    gl_FragColor = texture2D(inputImageTexture, uv);
    
}
