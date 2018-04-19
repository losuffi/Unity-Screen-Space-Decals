Shader "Decal/DecalCommonShader"
{
	Properties
	{		
		_MainColor("Color",Color)=(1,1,1,1)
		_MainTex ("Diffuse", 2D) = "white" {}
		_SpecularMap("Specular Map",2D)="white"{}
		_NormalMap("Normal Map",2D) = "white"{}
		_Gloss("Gloss",Range(0,10.0))=1.0
		_Roughness("Roughness",Range(0.001,1.0)) = 0.001
		_BlendFactor("BlendFactor",Range(0,1.0)) = 0.001
	}
	SubShader
	{
		Pass
		{
			Fog { Mode Off } 
			ZWrite Off
			Blend SrcAlpha OneMinusSrcAlpha

			CGPROGRAM
			#pragma target 3.0
			#pragma exclude_renderers nomrt

			#include "UnityCG.cginc"
			#include "..//Include/DecalBase.cginc"
			#pragma vertex DeferredDecalVert
			#pragma fragment frag
			void frag(
                VertexOutput i, 
				out half4 outDiffuse : COLOR0,
				out half4 outSpecRoughness : COLOR1,
				out half4 outNormal : COLOR2,
                out half4 outEmission : COLOR3
			)
			{
				Decal decal;
				decal=GetDeferredDecal(i.ray,i.screenUV);
				half3 nor = UnpackNormal(tex2D(_NormalMap, decal.localUV));
				half3x3 norMat = half3x3(i.oriSpace[0], i.oriSpace[2], i.oriSpace[1]);
				half3 worldNor = mul(nor, norMat);
				half3 normalWorld = worldNor + decal.normal;


				half3 diffuse=saturate(dot(_LightDir,normalWorld) *0.5+0.5)*_LightColor;
				half4 specularFactor=tex2D(_SpecularMap,decal.localUV);  
				half3 view=i.eyeVec;
				half3 s= (pow(max(dot((view+_LightDir),normalWorld),0.0),_Gloss))*_LightColor;
				half4 col = tex2D (_MainTex, decal.localUV)*_MainColor;
				half3 colo = col + diffuse;
				DeferredSource source=GetSource(decal.screenPos);
				half4 spec = specularFactor* half4(s,1);
				clip(col.a-0.2);
				outDiffuse = lerp(source.Albedo, half4(colo, col.a), col.a);
				outSpecRoughness=lerp(source.RoughnessSpec,spec,col.a);
				outNormal = lerp(source.Normal, half4(normalWorld*0.5 + 0.5, 1), col.a);
			}
			ENDCG
		}		
	}

	Fallback Off
}
