attribute vec4 vPosition;
attribute vec2 vTexCoord;
varying vec2 fTexCoord;

void main()
{
   gl_Position = vPosition;
   fTexCoord = vTexCoord;
}
