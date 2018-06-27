#include "UnityStandardCore.cginc"
#include "UnityDeferredLibrary.cginc"
sampler2D _CameraGBufferTexture2;
struct ProjectionInput
{
	float4 pos : SV_POSITION;
	float4 screenPos : TEXCOORD0;
	float3 ray : TEXCOORD1;

	half3 worldForward : TEXCOORD2;
	half3 worldUp : TEXCOORD3;

	half3 eyeVec : TEXCOORD4;
    float4 ambientOrLightmapUV:TEXCOORD5;
	UNITY_VERTEX_INPUT_INSTANCE_ID
};
struct FragmentCustomData
{
    half alpha;
    half oneMinusReflectivity;
    half smoothness;

    half3 diffColor;
    half3 specColor;
    float3 normalWorld;
    float3 eyeVec;
    float3 posWorld;
};
float4 texCustom(float2 uv)
{
    float4 texcoord;
    texcoord.xy = TRANSFORM_TEX(uv, _MainTex); // Always source from uv0
    texcoord.zw = TRANSFORM_TEX(uv, _DetailAlbedoMap);
    return texcoord;
}
ProjectionInput vertStandard(VertexInput v)
{
    ProjectionInput p;
    UNITY_SETUP_INSTANCE_ID(p);
    UNITY_TRANSFER_INSTANCE_ID (v, p);

    p.pos=UnityObjectToClipPos(float4(v.vertex.xyz,1));
    p.screenPos=ComputeScreenPos(p.pos);
    p.ray=UnityObjectToViewPos(v.vertex)*float3(-1,-1,1);
    float4 posWorld=mul(unity_ObjectToWorld,v.vertex);
    p.eyeVec=posWorld.xyz-_WorldSpaceCameraPos;
    p.worldForward=mul(unity_ObjectToWorld,float3(0,0,1));
    p.worldUp=mul(unity_ObjectToWorld,float3(0,1,0));
    p.ambientOrLightmapUV = 0;
    return p;
}
float3x3 SurfaceToWorldMat(float3 worldUp,float3 surfaceNormal)
{
    float3 binormal=normalize(cross(worldUp,surfaceNormal));
    float3 tangentWorld=normalize(cross(surfaceNormal,binormal));
    return float3x3(tangentWorld,binormal,surfaceNormal);
}
float4 Txt2D_Sample(float2 uv,sampler2D tex,float4 offset)
{
    uv=uv.xy*offset.xy+offset.zw;
    return tex2D(tex,uv);
}
float3 worldNormal(float2 uv,float3x3 mat)
{
    float3 normalMap=UnpackNormal(tex2D(_BumpMap,uv));
    normalMap.z/=clamp(_BumpScale,0.1,4);
    normalMap=normalize(normalMap);
    return normalize(mul(mat,normalMap));
}
inline FragmentCustomData SetFragmentCustomData(float2 uv,float3 worldUp,float3 backgroundNormal,float3 eyeVec,float3 posWorld)
{
    FragmentCustomData o;
    float4 i_tex=texCustom(uv);
    float3x3 normalMat=SurfaceToWorldMat(worldUp,backgroundNormal);
    o.normalWorld=worldNormal(uv,normalMat);
    half alpha = Alpha(uv);
    #if defined(_ALPHATEST_ON)
        clip (alpha - _Cutoff);
    #endif
    i_tex = Parallax(i_tex,float3(0,0,0));
    half2 metallicGloss = MetallicGloss(uv);
    half metallic = metallicGloss.x;
    half smoothness = metallicGloss.y; // this is 1 minus the square root of real roughness m.

    half oneMinusReflectivity;
    half3 specColor;
    //half3 albedo=_Color.rgb*tex2D(_MainTex,i_tex.xy).rgb;
    half3 diffColor = DiffuseAndSpecularFromMetallic (Albedo(i_tex), metallic, /*out*/ specColor, /*out*/ oneMinusReflectivity);
    o.diffColor = diffColor;
    o.specColor = specColor;
    o.oneMinusReflectivity = oneMinusReflectivity;
    o.smoothness = smoothness;
    //o.diffColor = PreMultiplyAlpha (o.diffColor, alpha, o.oneMinusReflectivity, /*out*/ o.alpha);
    o.eyeVec=eyeVec;
    o.posWorld=posWorld;
    return o;
}

inline UnityGI FragmentCustomGI (FragmentCustomData s, half occlusion, half4 i_ambientOrLightmapUV, half atten, UnityLight light, bool reflections)
{
    UnityGIInput d;
    d.light = light;
    d.worldPos = s.posWorld;
    d.worldViewDir = -s.eyeVec;
    d.atten = atten;
    #if defined(LIGHTMAP_ON) || defined(DYNAMICLIGHTMAP_ON)
        d.ambient = 0;
        d.lightmapUV = i_ambientOrLightmapUV;
    #else
        d.ambient = i_ambientOrLightmapUV.rgb;
        d.lightmapUV = 0;
    #endif

    d.probeHDR[0] = unity_SpecCube0_HDR;
    d.probeHDR[1] = unity_SpecCube1_HDR;
    #if defined(UNITY_SPECCUBE_BLENDING) || defined(UNITY_SPECCUBE_BOX_PROJECTION)
      d.boxMin[0] = unity_SpecCube0_BoxMin; // .w holds lerp value for blending
    #endif
    #ifdef UNITY_SPECCUBE_BOX_PROJECTION
      d.boxMax[0] = unity_SpecCube0_BoxMax;
      d.probePosition[0] = unity_SpecCube0_ProbePosition;
      d.boxMax[1] = unity_SpecCube1_BoxMax;
      d.boxMin[1] = unity_SpecCube1_BoxMin;
      d.probePosition[1] = unity_SpecCube1_ProbePosition;
    #endif

    if(reflections)
    {
        Unity_GlossyEnvironmentData g = UnityGlossyEnvironmentSetup(s.smoothness, -s.eyeVec, s.normalWorld, s.specColor);
        // Replace the reflUVW if it has been compute in Vertex shader. Note: the compiler will optimize the calcul in UnityGlossyEnvironmentSetup itself

        return UnityGlobalIllumination (d, occlusion, s.normalWorld, g);
    }
    else
    {
        return UnityGlobalIllumination (d, occlusion, s.normalWorld);
    }
}
void fragStandard (
    ProjectionInput i,
    out half4 outGBuffer0 : SV_Target0,
    out half4 outGBuffer1 : SV_Target1,
    out half4 outGBuffer2 : SV_Target2,
    out half4 outEmission : SV_Target3          // RT3: emission (rgb), --unused-- (a)
)
{
    // #if (SHADER_TARGET < 30)
    //     outGBuffer0 = 1;
    //     outGBuffer1 = 1;
    //     outGBuffer2 = 0;
    //     outEmission = 0;
    //     #if defined(SHADOWS_SHADOWMASK) && (UNITY_ALLOWED_MRT_COUNT > 4)
    //         outShadowMask = 1;
    //     #endif
    //     return;
    // #endif
    UNITY_APPLY_DITHER_CROSSFADE(i.pos.xy);

    i.ray=i.ray*(_ProjectionParams.z/i.ray.z);
    float2 uv= i.screenPos.xy/i.screenPos.w;  
    float depth=Linear01Depth(SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture,uv));
    float4 vpos=float4(i.ray*depth,1);
    float3 wpos=mul(unity_CameraToWorld,vpos).xyz;
    float3 opos=mul(unity_WorldToObject,float4(wpos,1)).xyz;
    clip(float3(0.5,0.5,0.5)-abs(opos));
    float3 backgroundNormal=UnpackNormal(tex2D(_CameraGBufferTexture2,uv)) ;
    uv=opos.xz+0.5;
    // outGBuffer0=_Color;
    // outGBuffer1=_Color;
    // outGBuffer2=_Color;
    // outEmission=_Color;
    FragmentCustomData s=SetFragmentCustomData(uv,i.worldUp,backgroundNormal,i.eyeVec,wpos);

    UNITY_APPLY_DITHER_CROSSFADE(i.pos.xy);
    UnityLight dummyLight=DummyLight();
    float atten=1;
    float occlusion=Occlusion(uv);
    #if UNITY_ENABLE_REFLECTION_BUFFERS
    bool sampleReflectionsInDeferred = false;
#else
    bool sampleReflectionsInDeferred = true;
#endif
    UnityGI gi = FragmentCustomGI (s, occlusion, i.ambientOrLightmapUV, atten, dummyLight, sampleReflectionsInDeferred);
    half3 emissiveColor = UNITY_BRDF_PBS (s.diffColor, s.specColor, s.oneMinusReflectivity, s.smoothness, s.normalWorld, -s.eyeVec, gi.light, gi.indirect).rgb;
    #ifdef _EMISSION
        emissiveColor += Emission (uv);
    #endif

    #ifndef UNITY_HDR_ON
        emissiveColor.rgb = exp2(-emissiveColor.rgb);
    #endif

    UnityStandardData data;
    data.diffuseColor   = s.diffColor;
    data.occlusion      = occlusion;
    data.specularColor  = s.specColor;
    data.smoothness     = s.smoothness;
    data.normalWorld    = s.normalWorld;

    UnityStandardDataToGbuffer(data, outGBuffer0, outGBuffer1, outGBuffer2);
     outEmission=half4(emissiveColor,1);
}