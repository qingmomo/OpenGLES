attribute vec4 Position;

attribute vec2 TexCoordIn;
varying vec2 TexCoordOut;

uniform mat4 Projection;
uniform mat4 ModelView;

void main(){

    gl_Position = Projection * ModelView * Position;

    TexCoordOut = vec2(TexCoordIn.x, TexCoordIn.y);
}
