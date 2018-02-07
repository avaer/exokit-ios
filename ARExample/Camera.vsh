attribute vec4 position;
attribute vec2 texCoord;

varying vec2 textureCoordinate;

void main()
{
    gl_Position = vec4(position.y, -position.x, position.z, position.w);
    textureCoordinate = texCoord;
}

