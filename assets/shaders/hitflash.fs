#version 330

in vec2 fragTexCoord;
in vec4 fragColor;

out vec4 finalColor;

uniform sampler2D texture0;
uniform vec4 colDiffuse;

void main() {
    // Standard texture sample
    vec4 texelColor = texture(texture0, fragTexCoord);

    // Solid tint: use the tint color's RGB, but keep the texture's Alpha
    // We also multiply by colDiffuse.a so overall alpha/fade still works.
    finalColor = vec4(colDiffuse.rgb, texelColor.a * colDiffuse.a);
}
