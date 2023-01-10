
void main()
{
	vec4 c = texture(InputTexture, TexCoord);
	float red = clamp(0.0, c.r - c.g - c.b, 1.0);
	vec3 lum = vec3(pow(dot(c.rgb, vec3(0.3,0.56,0.14)), 1/0.75));
	vec3 z = mix(lum, vec3(0.8 + pow(lum.r, 0.5) * 0.8, 0.0, 0.0), red);
	FragColor = vec4(z, 1.0);
}
