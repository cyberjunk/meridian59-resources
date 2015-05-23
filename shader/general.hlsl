struct VOut
{
	float4 p    : POSITION;
	float2 uv   : TEXCOORD0;
	float4 wp   : TEXCOORD1;
};

void ambient_vs(
	float4 p : POSITION,
	float2 uv : TEXCOORD0,
	uniform float4x4 wvpMat,
	uniform float4x4 texturemat,
	out float4 oPos : POSITION,
	out float2 oUV : TEXCOORD0)
{
	oPos = mul(wvpMat, p);
	oUV = mul(texturemat,float4(uv,0,1)).xy;
}

float4 ambient_ps(
	in float2 uv : TEXCOORD0,
	uniform float3 ambient,
	uniform float3 colormodifier,
	uniform float opaque,
	uniform sampler2D dMap): COLOR0
{
    return tex2D(dMap, uv) * float4(
		ambient[0] * colormodifier[0],
		ambient[1] * colormodifier[1],
		ambient[2] * colormodifier[2],		
		1.0 * opaque);
}

VOut diffuse_vs(
	float4 p : POSITION,
	float2 uv : TEXCOORD0,
	uniform float4x4 wMat,
	uniform float4x4 wvpMat,
	uniform float4x4 texturemat)
{
	VOut OUT;
	
	OUT.wp = mul(wMat, p);
	OUT.p = mul(wvpMat, p);
	OUT.uv = mul(texturemat,float4(uv,0,1)).xy;
 
	return OUT;
}
 
float4 diffuse_ps(
	float2 uv : TEXCOORD0,
	float4 wp : TEXCOORD1,
	uniform float3 lightDif0,
	uniform float4 lightPos0,
	uniform float4 lightAtt0,
	uniform float3 colormodifier,
	uniform float opaque,
	uniform sampler2D diffuseMap : TEXUNIT0): COLOR0
{  
	// distance, attenuation
	half lightDist = length(lightPos0.xyz - wp.xyz) / lightAtt0.r;
	half la = 1.0 - (lightDist * lightDist);

	// the argb value from diffuse texture
	float4 diffuseTex = tex2D(diffuseMap, uv);
	
	// the outputcolor RGB, no alpha
	float3 diffuseContrib = (lightDif0 * diffuseTex.rgb * la);

	// return outputcolor RGB with alpha from texture
	return float4(
		diffuseContrib[0] * colormodifier[0],
		diffuseContrib[1] * colormodifier[1],
		diffuseContrib[2] * colormodifier[2],
		diffuseTex.a * opaque);
}

void invisible_vs(
		float4 pos			: POSITION,
		float4 normal		: NORMAL,
		float2 tex			: TEXCOORD0,
		
		out float4 oPos		: POSITION,
		out float3 noiseCoord : TEXCOORD0,
		out float4 projectionCoord : TEXCOORD1,
		out float3 oEyeDir : TEXCOORD2, 
		out float2 oUV : TEXCOORD3, 

		uniform float4x4 worldViewProjMatrix,
		uniform float4x4 texturemat,
		uniform float3 eyePosition, // object space
		uniform float timeVal,
		uniform float scale,  // the amount to scale the noise texture by
		uniform float scroll, // the amount by which to scroll the noise
		uniform float noise  // the noise perturb as a factor of the  time
		)
{
	oPos = mul(worldViewProjMatrix, pos);
	// Projective texture coordinates, adjust for mapping
	float4x4 scalemat = float4x4(0.5,   0,   0, 0.5, 
	                               0,-0.5,   0, 0.5,
								   0,   0, 0.5, 0.5,
								   0,   0,   0,   1);
	projectionCoord = mul(scalemat, oPos);
	// Noise map coords
	noiseCoord.xy = (tex + (timeVal * scroll)) * scale;
	noiseCoord.z = noise * timeVal;

	oEyeDir = normalize(pos.xyz - eyePosition); 
	
	oUV = mul(texturemat,float4(tex,0,1)).xy; 
	
}

void invisible_ps(
		float4 pos					: POSITION,
		float3 noiseCoord			: TEXCOORD0,
		float4 projectionCoord		: TEXCOORD1,
		float3 eyeDir				: TEXCOORD2,
		float2 uv					: TEXCOORD3,
		
		out float4 col		: COLOR,
		
		uniform float4 tintColour,
		uniform float noiseScale, 
		uniform sampler2D diffuseMap : register(s0),
		uniform sampler2D noiseMap : register(s1),
		uniform sampler2D refractMap : register(s2)
		)
{	
	// the argb value from diffuse texture
	float4 diffuseTex = tex2D(diffuseMap, uv);
	
	if (diffuseTex.a > 0.0)
	{
		// Do the tex projection manually so we can distort _after_
		float2 final = projectionCoord.xy / projectionCoord.w;

		// Noise
		float3 noiseNormal = (tex2D(noiseMap, (noiseCoord.xy / 5)).rgb - 0.5).rbg * noiseScale;
		final += noiseNormal.xz;

		// Final colour
		col = tex2D(refractMap, final) + tintColour;
	}	
	else
	{
		col = diffuseTex;
	}
}




struct VS_OUTPUT {
   float4 Pos:    POSITION;
   float3 uvw:    TEXCOORD0;
   float3 normal: TEXCOORD1;
   float3 vVec:   TEXCOORD2;
};

VS_OUTPUT water_vs(
	float4 Pos: POSITION, 
	float3 normal: NORMAL,
	uniform float4x4 worldViewProj_matrix,
	uniform float3 scale,
	uniform float2 waveSpeed,
	uniform float noiseSpeed,
	uniform float time_0_X,
	uniform float3 eyePosition)
{
   VS_OUTPUT Out;

   Out.Pos    = mul(worldViewProj_matrix, Pos); 
   Out.uvw    = Pos.xyz * scale;
   Out.uvw.xz += waveSpeed * time_0_X;
   Out.uvw.y  += Out.uvw.z + noiseSpeed * time_0_X;  
   Out.vVec   = Pos.xyz - eyePosition;
   Out.normal = normal;

   return Out;
}

float4 water_ps(
	float4 Pos: POSITION,
	float3 uvw: TEXCOORD0, 
	float3 normal: TEXCOORD1, 
	float3 vVec: TEXCOORD2,
	uniform sampler2D noise,
	uniform sampler2D diffusetex,
	uniform float3 ambient) : COLOR
{
   float3 noisy = tex2D(noise, uvw.xy).xyz;
   float3 bump = 2 * noisy - 1;
   
   bump.xz *= 0.15;
   bump.y = 0.8 * abs(bump.y) + 0.2;
   bump = normalize(normal + bump);

   float3 normView = normalize(vVec);
   float3 reflVec = reflect(normView, bump);
   
   reflVec.z = -reflVec.z;
   
   float4 reflcol = tex2D(diffusetex, reflVec); 

   ambient = ambient + float3(0.01, 0.01, 0.01);
   
   return float4(ambient, 0) * reflcol;
}
