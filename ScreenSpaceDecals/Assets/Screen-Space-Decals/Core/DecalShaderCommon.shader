Shader "Decal/DecalCommonShader"
{
	Properties
	{		
		_MainColor("Color",Color)=(1,1,1,1)
		_MainTex ("Diffuse", 2D) = "white" {}
		_SpecularMap("Specular Map",2D)="white"{}
		_NormalMap("Normal Map",2D) = "white"{}
		_NormalFlip("Normal Flip",Range(0,4.0))=1.0
		_NormalMapScale("Normal Scale",Range(0,4.0))=1.0
		_Metallic("Metallic",Range(0,1.0))=1.0
		_Glossiness("Glossiness",Range(0,1.0)) = 0.001
		_Cutoff("Cutoff",Range(0,1))=0
		_EmissionColor("Color",Color)=(1,1,1,1)
		_EmissionMap("Emission Map",2D)="white"{}
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
				decal=GetDeferredDecal(i.ray,i.screenUV,i.oriSpace[1]);
				DeferredSource source=GetSource(decal.screenPos);
				FragmentCommonData fragment=FragmentMetallic(decal,i.oriSpace[0],i.eyeVec);
				half3 a=DeferredAmbient(fragment);
				a+=EmissionAlpha(decal.localUV);
				half3 c= fragment.diffuse;
				outDiffuse=half4(c,fragment.occlusion);
				half4 s= half4(fragment.specular,fragment.oneMinusRoughness);
				outSpecRoughness=s;
				half3 n=fragment.normalWorld;
				outNormal=half4(n*0.5+0.5,1);
				outEmission=EmissionOutput(half4(a,1),fragment.occlusion);
			}
			ENDCG
		}		
	}

	Fallback Off
}
