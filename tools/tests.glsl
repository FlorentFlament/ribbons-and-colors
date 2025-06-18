const float xa[] = float[](51.0, 2.0, 11.0, 11.0, 2.0, 2.0, 2.0, 2.0);
const float xb[] = float[]( 0.0, 0.5,  0.0,  0.0, 0.5, 0.0, 1.0, 0.5);
const float ya[] = float[](51.0,31.0, 31.0,  2.0, 2.0, 1.0, 1.0, 1.0);
const float yb[] = float[]( 0.0, 0.0,  0.0,  0.5, 0.5, 1.0, 1.0, 1.0);

const float speed = 1.0;

float square(float val) {
  /* returns val % 2*/
  return float( int(val) % 2 );
}

/* time is itime */
void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    // Normalized pixel coordinates (from 0 to 1)
    vec2 uv = fragCoord/iResolution.xy;

    // Time varying pixel color
    vec3 x = square(xa[int(speed*iTime)%7]*uv.x + xb[int(speed*iTime)%7]) * vec3(0,1.0,1.0);
    vec3 y = square(ya[int(speed*iTime)%7]*uv.y + yb[int(speed*iTime)%7]) * vec3(0,1.0,1.0);
    vec3 col = x*y;

    // Output to screen
    fragColor = vec4(col,1.0);
}