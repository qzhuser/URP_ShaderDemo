Shader "QZH/CircleHolo"
{
    Properties
    {
		[Header(HoloEffect)]
		[Space]
        [HDR]_ColorTint("Color Tint",Color)=(1,1,1,1)
        //_WorldPos("World Pos",Vector)=(0,0,0,0)
		//三角形扩散的大小
		_DiffusedAmount("Amount",float)=1
		_grow("Grow",Range(0,1))=0
        [HDR]_LineColor ("Line Color", Color) = (1,1,1,1)
		_LineMainTex ("Main Texture", 2D) = "white" {}
		_LineThickness ("Line Thickness", Range(0.0,5.0)) = 1
		_growWidth("GrowWidth",float)=3
		_Heigh("Heigh",float)=30
		_TesllAmount("Tess Amount",Int)=1
		[Enum(UnityEngine.Rendering.BlendMode)] _SrcBlend("Src Blend Model",Float)=1
		[Enum(UnityEngine.Rendering.BlendMode)] _DstBlend("Dst Blend Model",Float)=1

    }
    SubShader
    {

        Pass{
            Tags { "RenderType"="Transparent" "Queue"="Transparent" }

			Blend [_SrcBlend] [_DstBlend] 
			ZWrite Off
			//ZWrite On
			Cull Off
			CGPROGRAM
				#pragma target 5.0
				#include "UnityCG.cginc"
				//#include "UCLA GameLab Wireframe Functions.cginc"
				#pragma vertex UCLAGL_vert
				#pragma fragment UCLAGL_frag
				#pragma geometry UCLAGL_geom
				#pragma hull MyHullProgram
				#pragma domain MyDomainProgram
				//gpu instance
				#pragma multi_compile_instancing

				struct UCLAGL_v2t
				{

					float4 vertex : INTERNALTESSPOS;
					float3 normal:NORMAL;
					float4 tangent : TANGENT;
					float2 uv:TEXCOORD0;
					float2 uv1 : TEXCOORD2;
					float2 uv2 : TEXCOORD3;
				};
				struct UCLAGL_t2g
				{
					float4 pos:POSITION;
					float2 uv:TEXCOORD0;
					float3 normal:NORMAL;
					float3 modelPos:TEXCOORD1;
				};

				// Geometry to  UCLAGL_fragment
				struct UCLAGL_g2f
				{
					float4	pos		: SV_POSITION;
					float2	uv		: TEXCOORD0;
					float3  dist	: TEXCOORD1;
					float3 worldpos:TEXCOORD2;
					float3 modelPos:TEXCOORD3;
				};
				struct TessellationFactors
				{
					float edge[3] : SV_TessFactor;
					float inside : SV_InsideTessFactor;

				};
				//struct TessellationControlPoint {
				//	float4 vertex : INTERNALTESSPOS;
				//	float3 normal : NORMAL;
				//	float4 tangent : TANGENT;
				//	float2 uv : TEXCOORD0;
				//	float2 uv1 : TEXCOORD1;
				//	float2 uv2 : TEXCOORD2;
				//};

				sampler2D _MainTex;
				float4 _MainTex_ST;
				float4 _ColorTint;
				//float4 _WorldPos;	
				float _DiffusedAmount;
				float _LineThickness;// 线框宽度
				float4 _LineColor;
				float4 _LineMainTex_ST;
				sampler2D _LineMainTex;
				float _grow;
				float _Heigh;
				float _growWidth;
				fixed _TesllAmount;

				UCLAGL_v2t UCLAGL_vert(appdata_full v)
				{
					UCLAGL_v2t output;
					//v.vertex.xyz+=v.normal*value*0.2;
					//output.pos =  UnityObjectToClipPos(v.vertex);
					//output.uv = TRANSFORM_TEX (v.texcoord, _LineMainTex);
					output.vertex=v.vertex;
					output.normal=v.normal;
					output.tangent=v.tangent;
					output.uv=v.texcoord;
					output.uv1=v.texcoord1;
					output.uv2=v.texcoord2;
					return output;
				}
				TessellationFactors MyPatchConstantFunction(InputPatch<UCLAGL_v2t,3> patch){
					TessellationFactors f;
					//对三条边分割，每条边分成三部分
					f.edge[0]=_TesllAmount;
					f.edge[1]=_TesllAmount;
					f.edge[2]=_TesllAmount;
					//计算三个新顶点的重心坐标
					f.inside=_TesllAmount;
					return f;
				}

				[UNITY_domain("tri")]
				[UNITY_outputcontrolpoints(3)]
				[UNITY_outputtopology("triangle_cw")]
				[UNITY_partitioning("integer")]
				[UNITY_patchconstantfunc("MyPatchConstantFunction")]
				UCLAGL_v2t MyHullProgram(InputPatch<UCLAGL_v2t,3> patch,uint id:SV_OUTPUTCONTROLPOINTID){
					return patch[id];
				}

				[UNITY_domain("tri")]
				UCLAGL_t2g MyDomainProgram(TessellationFactors factors,
				OutputPatch<UCLAGL_v2t,3> patch,
				float3 bary:SV_DOMAINLOCATION){
					UCLAGL_t2g data;
					//求出新顶点的属性
					float4 vertex=patch[0].vertex*bary.x+patch[1].vertex*bary.y+patch[2].vertex*bary.z;
					float3 normal=patch[0].normal*bary.x+patch[1].normal*bary.y+patch[2].normal*bary.z;
					data.pos =  UnityObjectToClipPos(vertex);
					data.modelPos=vertex.xyz;

					data.normal=normal;
					data.uv =patch[0].uv*bary.x+patch[1].uv*bary.y+patch[2].uv*bary.z;
					return data;
				}



				half GetValue(float3 modelPos){
					float3 worldPos=mul(unity_ObjectToWorld,modelPos);
					//_grow=(sin(_Time.y*0.5)*sin(_Time.y*0.5));
					float t=pow(_grow,4);
					float value=1-smoothstep(worldPos.y-_growWidth,worldPos.y,t*_Heigh);
					return value;
				}
				
				// Geometry Shader
				[maxvertexcount(3)]
				void UCLAGL_geom(triangle UCLAGL_t2g p[3], inout TriangleStream<UCLAGL_g2f> triStream)
				{
					//获得每个三角面的垂直向量
					float3 dirModel1=p[0].modelPos-p[1].modelPos;
					float3 dirModel2=p[0].modelPos-p[2].modelPos;
					float3 modelN=normalize(cross(dirModel1,dirModel2));

					

					float3 temp1=p[0].modelPos+modelN*_DiffusedAmount*GetValue(p[0].modelPos);
					float3 temp2=p[1].modelPos+modelN*_DiffusedAmount*GetValue(p[1].modelPos);
					float3 temp3=p[2].modelPos+modelN*_DiffusedAmount*GetValue(p[2].modelPos);
					
					float4 clipPos1=UnityObjectToClipPos(float4(temp1,1.0));
					float4 clipPos2=UnityObjectToClipPos(float4(temp2,1.0));
					float4 clipPos3=UnityObjectToClipPos(float4(temp3,1.0));

					//视口坐标
					float2 p0 = _ScreenParams.xy * clipPos1.xy / clipPos1.w;
					float2 p1 = _ScreenParams.xy * clipPos2.xy / clipPos2.w;
					float2 p2 = _ScreenParams.xy * clipPos3.xy / clipPos3.w;

					
					//三条边
					float2 v0 = p2 - p1;
					float2 v1 = p2 - p0;
					float2 v2 = p1 - p0;

					//三角形的面积
 					float area = abs(v1.x*v2.y - v1.y * v2.x);

					//面积除于边长 当前点距离每个边的长度
					float dist0 = area / length(v0);
					float dist1 = area / length(v1);
					float dist2 = area / length(v2);
	
					UCLAGL_g2f pIn;
	
					//add the first point
					pIn.pos = clipPos1;
					pIn.modelPos=temp1;
					pIn.uv = p[0].uv;
					pIn.worldpos=mul(unity_ObjectToWorld,temp1);
					pIn.dist = float3(dist0,0,0);
					//pIn.worldPos=
					triStream.Append(pIn);

					//add the second point
					pIn.pos =  clipPos2;
					pIn.modelPos=temp2;
					pIn.uv = p[1].uv;
					pIn.worldpos=mul(unity_ObjectToWorld,temp2);
					pIn.dist = float3(0,dist1,0);
					triStream.Append(pIn);
	
					//add the third point
					pIn.pos = clipPos3;
					pIn.modelPos=temp3;
					pIn.uv = p[2].uv;
					pIn.worldpos=mul(unity_ObjectToWorld,temp3);
					pIn.dist = float3(0,0,dist2);
					triStream.Append(pIn);


					triStream.RestartStrip();

					// pIn.pos = (p[0].pos+p[1].pos+p[2].pos)/3;
					// pIn.uv = (p[0].uv+p[1].uv+p[2].uv)/3;
					// pIn.worldpos=(p[0].worldPos+p[1].worldPos+p[2].worldPos)/3;
					// pIn.dist = float3(dist0,dist1,dist2);
					// triStream.Append(pIn);
				} 
				//顶点之间插值 获得每个像素距离三边的距离
				// Fragment Shader
				float4 UCLAGL_frag(UCLAGL_g2f input) : COLOR
				{	
					//底色
					//fixed3 worldPos=mul(unity_ObjectToWorld,v.worldPos).xyz;
					//fixed high=smoothstep(_WorldPos.x,_WorldPos.y,input.worldpos.y);
			        fixed4 col = _ColorTint*0.8;
			        //col*=high;

					//获取该点到附近三条边最短的距离
					float val = min( input.dist.x, min( input.dist.y, input.dist.z));
	
					//添加宽度 也可以直接与宽度值比较
					val = exp2( -1/_LineThickness * val * val );
		
					//
					float4 targetColor = _LineColor * tex2D( _LineMainTex, input.uv);
					//float4 transCol = _LineColor * tex2D( _LineMainTex, input.uv);
					// float fre=120;
					// float va=saturate(sin(input.worldpos.x*fre))*saturate(sin(input.worldpos.y*fre))*saturate(sin(input.worldpos.z*fre));
					// col.a*=va;
					half a=smoothstep(input.worldpos.y,input.worldpos.y+_growWidth,_grow*_Heigh);
					float4 final=val * targetColor+(1-val)*col;
					//final.a*=val;
					return final;
				}
			
			ENDCG
        }
    }
}
