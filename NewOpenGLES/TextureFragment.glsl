uniform sampler2D ourTexture;

varying mediump vec2 TexCoordOut;

void main(){
    gl_FragColor = texture2D(ourTexture, TexCoordOut);
}
