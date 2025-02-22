/*
[configuration]
[OptionRangeFloat]
GUIName = Blur Area
OptionName = BLUR_SIZE
MinValue = 0.0
MaxValue = 10.0
StepAmount = 0.1
DefaultValue = 1.6

[OptionRangeFloat]
GUIName = Brightness Boost
OptionName = BRIGHTNESS_BOOST
MinValue = 0.0
MaxValue = 5.0
StepAmount = 0.01
DefaultValue = 1.25

[OptionRangeFloat]
GUIName = Distortion amount
OptionName = DISTORTION_FACTOR
MinValue = 0.0
MaxValue = 10.0
StepAmount = 0.1
DefaultValue = 4.0

[OptionRangeFloat]
GUIName = Zoom adjustment
OptionName = SIZE_ADJUST
MinValue = 0.0
MaxValue = 1.0
StepAmount = 0.025
DefaultValue = 0.5

[OptionRangeFloat]
GUIName = Aspect Ratio adjustment
OptionName = ASPECT_ADJUST
MinValue = 0.0
MaxValue = 1.0
StepAmount = 0.025
DefaultValue = 0.5

[OptionRangeFloat]
GUIName = Kalman Gain
OptionName = kalman
MinValue = 0.0
MaxValue = 1.0
StepAmount = 0.001
DefaultValue = 0.5

[OptionRangeFloat]
GUIName = Antialiasing Samples
OptionName = alias_samples
MinValue = 1.0
MaxValue = 100.0
StepAmount = 1.0
DefaultValue = 4.0

[OptionBool]
GUIName = Progressive scan
OptionName = progressive_scan
DefaultValue = false

[OptionBool]
GUIName = Scanline Antialiasing
OptionName = enable_antialias
DefaultValue = false

[OptionBool]
GUIName = Debug RNG
OptionName = debug_rng
DefaultValue = false

[/configuration]
*/

SSBO_BINDING(3) coherent buffer decay
{
    float4 decaybuf[];
};

//IMAGE_BINDING(rgba32f, 4) uniform shadow_mask;

float rand(float2 xy)
{
    //float x = fract(sin(0.00001 * xy.x * GetTime()) * 43758.5453123);
    //float y = fract(sin(0.00001 * xy.y * (GetTime() + 0.1)) * 43758.5453123);

    //return float2(x, y);
    return fract(sin(dot(xy, vec2(12.9898,78.233))) * GetTime());
}

float4 scanline_sample(float2 uv)
{
  int wincoordx = int(floor(GetTargetResolution().x * uv.x));
  int wincoordy = int(floor(GetTargetResolution().y * uv.y));

  int bufcoordx = int(floor(GetResolution().x * uv.x));
  int bufcoordy = int(floor(GetResolution().y * uv.y));
  int decayindex = bufcoordx + (bufcoordy * int(GetResolution().x));

  float2 buffered_uv = float2((float(bufcoordx) * GetInvResolution().x), (float(bufcoordy) * GetInvResolution().y));
  float2 windowed_uv = float2((float(wincoordx) * GetInvTargetResolution().x), (float(wincoordy) * GetInvTargetResolution().y));

	float4 c0 = SampleLocation(buffered_uv);
  float4 cx, cy;
	float blursize = GetOption(BLUR_SIZE);
	float boost = GetOption(BRIGHTNESS_BOOST);
	
	//blur
	float4 blurtotal = c0;
	blurtotal += SampleLocation(buffered_uv + float2(-blursize, -blursize) * GetInvResolution());
	blurtotal += SampleLocation(buffered_uv + float2(-blursize, blursize) * GetInvResolution());
	blurtotal += SampleLocation(buffered_uv + float2( blursize, -blursize) * GetInvResolution());
	blurtotal += SampleLocation(buffered_uv + float2( blursize, blursize) * GetInvResolution());
	blurtotal += SampleLocation(buffered_uv + float2(-blursize, 0.0) * GetInvResolution());
	blurtotal += SampleLocation(buffered_uv + float2( blursize, 0.0) * GetInvResolution());
	blurtotal += SampleLocation(buffered_uv + float2( 0.0, -blursize) * GetInvResolution());
	blurtotal += SampleLocation(buffered_uv + float2( 0.0, blursize) * GetInvResolution());
	blurtotal /= 9.0;

  if ((frame_id & 1) == (bufcoordy & 1) || bool(progressive_scan))
    decaybuf[decayindex] += kalman * (blurtotal - decaybuf[decayindex]); // decay towards pixel data
  else
    decaybuf[decayindex] -= kalman * decaybuf[decayindex]; // decay towards zero

  c0 = decaybuf[decayindex];
  if (bool(enable_antialias))
  {
      for (int i = 0; i < int(round(alias_samples)); i++)
      {
          float2 pq = windowed_uv;
          pq.x += rand(uv * i) * GetInvTargetResolution().x;
          pq.y += rand(2 * uv * i) * GetInvTargetResolution().y;
         
          bufcoordx = int(floor(GetResolution().x * pq.x));
          bufcoordy = int(floor(GetResolution().y * pq.y));
          c0 += decaybuf[bufcoordx + bufcoordy * int(GetResolution().x)];
      }

      c0 /= round(alias_samples) + 1;

      //c0 = texture(shadow_mask, float3(uv, 1.0));
  }
  
  if (bool(debug_rng))
  {
      c0.x = rand(windowed_uv * 2);
      c0.y = rand(windowed_uv);
      //c0.x = 100 * (windowed_uv.x - buffered_uv.x); 
      //c0.y = 100 * (windowed_uv.y - buffered_uv.y); 
      //c0.z = float(decayindex) * GetInvResolution().x * GetInvResolution().y;
      //c0.z = GetResolution().x / 1024.;
  }

	// output
	//return float4(clamp(lineIntensity, 0.0, 1.125) * boost, 0, 0, 1);
	return c0 * boost;
  //return weights;
}
/*
*/

float2 distort_coordinates(float2 xy)
{
  // Base Cardboard distortion parameters
  float factor = GetOption(DISTORTION_FACTOR) * 0.01f;
  float ka = factor * 3.0f;
  float kb = factor * 5.0f;

  // size and aspect adjustment
  float sizeAdjust = 1.0f - GetOption(SIZE_ADJUST) + 0.5f;
  float aspectAdjustment = 1.25f - GetOption(ASPECT_ADJUST);

  // convert coordinates to NDC space
  float2 fragPos = (xy - 0.5f) * 2.0f;

  // Calculate the source location "radius" (distance from the centre of the viewport)
  float destR = length(fragPos);

  // find the radius multiplier
  float srcR = destR * sizeAdjust + ( ka * pow(destR, 2.0) + kb * pow(destR, 4.0));

  // Calculate the source vector (radial)
  float2 correctedRadial = normalize(fragPos) * srcR;

  // fix aspect ratio
  float2 widenedRadial = correctedRadial * float2(aspectAdjustment, 1.0f);

  // Transform the coordinates (from [-1,1]^2 to [0, 1]^2)
  float2 uv = (widenedRadial/2.0f) + float2(0.5f, 0.5f); 

  return uv;

}

void main()
{
  float2 uv = distort_coordinates(GetCoordinates());

  float4 tex_sample;
  // Sample the texture at the source location
  if (clamp(uv, 0.0, 1.0) != uv)
  {
    // black if beyond bounds
    tex_sample = float4(0.0, 0.0, 0.0, 0.0);
  }
  else
  {
    tex_sample = scanline_sample(uv);
  }

  SetOutput(tex_sample);
}
