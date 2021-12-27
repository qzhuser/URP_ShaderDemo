Shader "Unlit/wireframe"
{
    Properties
    {
        [Header(HoloEffect)]
		[Space(10)]
        [HDR]_ColorTint("Color Tint",Color)=(1,1,1,1)
        //_WorldPos("World Pos",Vector)=(0,0,0,0)
		//三角形扩散的大小
		_DiffusedAmount("Amount",float)=1
		_grow("Grow",Range(0,1.0))=0
        [HDR]_LineColor ("Line Color", Color) = (1,1,1,1)
		_LineMainTex ("Main Texture", 2D) = "white" {}
		_LineThickness ("Line Thickness", Range(0.0,10.0)) = 1
		_growWidth("GrowWidth",float)=3
		_RealDis("(XMinMax)",Vector)=(0.0,0.0,0.0,0.0)

		[Enum(UnityEngine.Rendering.BlendMode)] _SrcBlend("Src Blend Model",Float)=1
		[Enum(UnityEngine.Rendering.BlendMode)] _DstBlend("Dst Blend Model",Float)=1
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

        Pass{
            Tags { "RenderType"="Transparent" "Queue"="Transparent" }

			Blend [_SrcBlend] [_DstBlend] 
			ZWrite Off
			//ZWrite On
			Cull Back
			HLSLPROGRAM
				#pragma target 5.0
				#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"
            	#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            	#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            	#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/ShaderGraphFunctions.hlsl"
            	#include "Packages/com.unity.shadergraph/ShaderGraphLibrary/ShaderVariablesFunctions.hlsl"
				//#include "UCLA GameLab Wireframe Functions.cginc"
				#pragma vertex UCLAGL_vert
				#pragma fragment UCLAGL_frag
				#pragma geometry UCLAGL_geom
				//gpu instance
				#pragma multi_compile_instancing
				struct appdata{
					float4 vertex:SV_POSITION;
					float4 texcoord:TEXCOORD0;
					float3 normal:NORMAL;
				};
				
				struct UCLAGL_v2g
				{
					float4 pos:POSITION;
					float2 uv:TEXCOORD0;
					float3 normal:NORMAL;
					float3 worldpos:TEXCOORD1;
				};

				// Geometry to  UCLAGL_fragment
				struct UCLAGL_g2f
				{
					float4	pos		: POSITION;
					float2	uv		: TEXCOORD0;
					float3  dist	: TEXCOORD1;
					float3 worldpos:TEXCOORD2;
				};
				CBUFFER_START(UnityPerMaterial)
					float4 _ColorTint;
					//float4 _WorldPos;	
					float _DiffusedAmount;
					float _LineThickness;// 线框宽度
					float4 _LineColor;
					float4 _LineMainTex_ST;
					sampler2D _LineMainTex;
					float _grow;
					half4 _RealDis;
					float _growWidth;
				CBUFFER_END
				UCLAGL_v2g UCLAGL_vert(appdata v)
				{
					UCLAGL_v2g output;
					//output.modelPos=v.vertex.xyz;
					
					//v.vertex.xyz+=v.normal*value*0.2;
					output.normal=v.normal;
					output.pos =  TransformObjectToHClip(v.vertex);
					output.worldpos=TransformObjectToWorld(v.vertex.xyz);
					output.uv = v.texcoord.xy* _LineMainTex_ST.xy+_LineMainTex_ST.zw;
					return output;
				}
				half GetValue(float3 worldPos){
					//float3 worldPos=mul(unity_ObjectToWorld,modelPos);
					//_grow=(sin(_Time.y*0.5)*sin(_Time.y*0.5));
					float t=sin(_Time.x*3)*sin(_Time.x*3);
					if(t<=0.05||t>=0.95)
						return 0;

					float a = smoothstep(worldPos.x,worldPos.x+_growWidth,_RealDis.x+((1.0-t)*2*_RealDis.y))
							* (1.0-smoothstep(worldPos.x,worldPos.x+_growWidth,_RealDis.x+((1.0-t)*2*_RealDis.y)));
					return a;		
				}
				
				// Geometry Shader
				[maxvertexcount(3)]
				void UCLAGL_geom(triangle UCLAGL_v2g p[3], inout TriangleStream<UCLAGL_g2f> triStream)
				{

					
					//得到屏幕坐标（屏幕分辨率*ndc坐标）   p[0].pos.xy /  p[0].pos.w 透视除法
					float2 p0 = _ScreenParams.xy *  p[0].pos.xy /  p[0].pos.w;
					float2 p1 = _ScreenParams.xy *  p[1].pos.xy /  p[1].pos.w;
					float2 p2 = _ScreenParams.xy *  p[2].pos.xy /  p[2].pos.w;

					
					//三条边
					float2 v0 = p2 - p1;
					float2 v1 = p2 - p0;
					float2 v2 = p1 - p0;

					//三角形的面积
 					float area = abs(v1.x*v2.y - v1.y * v2.x);

					//面积除于边长 当前点距离对边的长度
					float dist0 = area / length(v0);
					float dist1 = area / length(v1);
					float dist2 = area / length(v2);
	
					UCLAGL_g2f pIn;
	
					//add the first point
					pIn.pos = p[0].pos;
					pIn.uv = p[0].uv;
					pIn.worldpos=p[0].worldpos;
					pIn.dist = float3(dist0,0,0);
					//pIn.worldPos=
					triStream.Append(pIn);

					//add the second point
					pIn.pos =  p[1].pos;
					pIn.uv = p[1].uv;
					pIn.worldpos=p[1].worldpos;
					pIn.dist = float3(0,dist1,0);
					triStream.Append(pIn);
	
					//add the third point
					pIn.pos = p[2].pos;
					pIn.uv = p[2].uv;
					pIn.worldpos=p[2].worldpos;
					pIn.dist = float3(0,0,dist2);
					triStream.Append(pIn);
					triStream.RestartStrip();
				} 
				//顶点之间插值 获得每个像素距离三边的距离
				// Fragment Shader
				float4 UCLAGL_frag(UCLAGL_g2f input) : COLOR
				{	
					//底色
					//half3 worldPos=mul(unity_ObjectToWorld,v.worldPos).xyz;
					//half high=smoothstep(_WorldPos.x,_WorldPos.y,input.worldpos.y);
			        half4 col = _ColorTint*0.8;
			        //col*=high;

					//获取该点到附近三条边最短的距离
					float val = min( input.dist.x, min( input.dist.y, input.dist.z));
	
					//添加宽度 也可以直接与宽度值比较（拿一个系数控制线的宽度）
					val = exp2( -1/_LineThickness * val * val );
		
					//
					float4 targetColor = _LineColor * tex2D( _LineMainTex, input.uv);
					//float4 transCol = _LineColor * tex2D( _LineMainTex, input.uv);
					float value=GetValue(input.worldpos);
					float4 final=val * targetColor;

					final.a*=value;
					return final;
				}
			
			ENDHLSL
        }
    }
}
