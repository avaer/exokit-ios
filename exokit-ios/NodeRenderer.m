//
//  ARRenderer.m
//  ARExample
//
//  Created by ZhangXiaoJun on 2017/7/5.
//  Copyright © 2017年 ZhangXiaoJun. All rights reserved.
//

#import "NodeRenderer.h"
#import "GLProgram.h"
#import "node-service.h"
#import <OpenGLES/ES2/gl.h>
#import <MetalKit/MetalKit.h>

struct ARData {
    GLfloat position[3];
    GLfloat texCoord[2];
    GLfloat normal[3];
    GLfloat color[4];
};

// The max number of command buffers in flight
static const NSUInteger kMaxBuffersInFlight = 3;

// The max number anchors our uniform buffer will hold
static const NSUInteger kMaxAnchorInstanceCount = 64;

// Structure shared between shader and C code to ensure the layout of shared uniform data accessed in
//    Metal shaders matches the layout of uniform data set in C code
typedef struct {
    // Camera Uniforms
    matrix_float4x4 projectionMatrix;
    matrix_float4x4 viewMatrix;
    
    // Lighting Properties
    vector_float3 ambientLightColor;
    vector_float3 directionalLightDirection;
    vector_float3 directionalLightColor;
    float materialShininess;
} SharedUniforms;

// Structure shared between shader and C code to ensure the layout of instance uniform data accessed in
//    Metal shaders matches the layout of uniform data set in C code
typedef struct {
    matrix_float4x4 modelMatrix;
} InstanceUniforms;

// The 256 byte aligned size of our uniform structures
static const size_t kAlignedSharedUniformsSize = (sizeof(SharedUniforms) & ~0xFF) + 0x100;
static const size_t kAlignedInstanceUniformsSize = ((sizeof(InstanceUniforms) * kMaxAnchorInstanceCount) & ~0xFF) + 0x100;
static const int FRAME_TIME_MAX = 1000 / 60;
static const int FRAME_TIME_MIN = FRAME_TIME_MAX / 5;

@interface NodeRenderer ()
{
    void *_sharedUniformBufferAddress;
    void *_anchorUniformBufferAddress;
    SharedUniforms *_sharedUniformBuffer;
    InstanceUniforms *_anchorUniformBuffer;
    uint8_t _uniformBufferIndex;
    NSUInteger _anchorInstanceCount;
    vector_float3 _anchorCenter;
    
    uint8_t _sharedUniformBufferOffset;
    uint8_t _anchorUniformBufferOffset;
    char *_modelMatrixNames[kMaxAnchorInstanceCount];
    
    
    GLuint _cubeBuffer;
    GLuint _cubeIndicesBuffer;
    // MetalKit mesh containing vertex data and index buffer for our anchor geometry
    GLKMesh *_cubeMesh;
    EAGLContext *_context;
    CVOpenGLESTextureCacheRef _coreVideoTextureCache;
  
    long lastFrameTime;
}
@end

@implementation NodeRenderer

- (void)dealloc
{
    for(int i = 0; i < kMaxAnchorInstanceCount; i++){
        free(_modelMatrixNames[i]);
    }
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        for(int i = 0; i < kMaxAnchorInstanceCount; i++){
            const char *name = [[NSString stringWithFormat:@"modelMatrix[%d]",i] UTF8String];
            char *copyName = malloc(strlen(name) + 1);
            strcpy(copyName, name);
            _modelMatrixNames[i]  = copyName;
        }
        
        _context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];

        if (!_context || ![EAGLContext setCurrentContext:_context]){
            NSAssert(NO, @"Failed to init gl context !");
            return nil;
        }
      
        const char *binPath = "node";
        NSString *mainBundlePathString = [[NSBundle mainBundle] bundlePath];
        NSString *scriptPathString = [NSString stringWithFormat:@"%@/%@", mainBundlePathString, @"html5.js"];
        const char *scriptPath = [scriptPathString UTF8String];
        const char *libPath = "lib";
        const char *dataPath = "data";
        const char *url = "http://192.168.0.13:8000/?e=hmd";
        const char *vrMode = "ar";
        NodeService_start(binPath, scriptPath, libPath, dataPath, url, vrMode, -1, -1);
      
        // NodeService_tick(5000);
        
        _anchorUniformBuffer = malloc(kAlignedInstanceUniformsSize * kMaxBuffersInFlight);
        _sharedUniformBuffer = malloc(kAlignedSharedUniformsSize * kMaxBuffersInFlight);
        
        _sceneSize = CGSizeZero;
    }
    return self;
}

- (void)drawCameraFrame:(ARFrame *)frame
{
    [_context setDebugLabel:@"Draw Camera Frame"];
    
    /* glDisable(GL_CULL_FACE);
    glEnable(GL_DEPTH_TEST);
    glDepthFunc(GL_ALWAYS);
    
    glClearColor(0, 0, 0, 0);
    glClear(GL_COLOR_BUFFER_BIT);
    [_program use];
    
    CVPixelBufferRef pixelBuffer = frame.capturedImage;
    [self createTextureFromPixelBuffer:pixelBuffer
                         outputTexture:&_capturedImageTextureY
                            pixeFormat:GL_LUMINANCE
                            planeIndex:0];
    [self createTextureFromPixelBuffer:pixelBuffer
                         outputTexture:&_capturedImageTextureCbCr
                            pixeFormat:GL_LUMINANCE_ALPHA
                            planeIndex:1];
    
    GLuint y = CVOpenGLESTextureGetName(_capturedImageTextureY);
    glBindTexture(GL_TEXTURE_2D, y);
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    
    GLuint cbcr = CVOpenGLESTextureGetName(_capturedImageTextureCbCr);
    glBindTexture(GL_TEXTURE_2D, cbcr);
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    
    static const GLfloat s_positions[] = {-1,-1,0,1,1,-1,0,1,-1,1,0,1,1,1,0,1};
    static const GLfloat s_texCoords[] = {0,1,
        1,1,
        0,0,
        1,0};
    
    GLuint position = [_program attributeIndex:@"position"];
    GLuint texCoord = [_program attributeIndex:@"texCoord"];
    GLuint capturedImageTextureY = [_program uniformIndex:@"capturedImageTextureY"];
    GLuint capturedImageTextureCbCr = [_program uniformIndex:@"capturedImageTextureCbCr"];
    
    glEnableVertexAttribArray(position);
    glEnableVertexAttribArray(texCoord);
    
    glVertexAttribPointer(position, 4, GL_FLOAT, GL_FALSE, 0, s_positions);
    glVertexAttribPointer(texCoord, 2, GL_FLOAT, GL_FALSE, 0, s_texCoords);
    
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, y);
    glUniform1i(capturedImageTextureY, 0);
    
    glActiveTexture(GL_TEXTURE1);
    glBindTexture(GL_TEXTURE_2D, cbcr);
    glUniform1i(capturedImageTextureCbCr, 1);
    
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
    
    CFRelease(_capturedImageTextureY);
    CFRelease(_capturedImageTextureCbCr); */
    
    [_context setDebugLabel:nil];
}

#pragma mark Prepare Data

- (void)_updateBufferStates {
    // Update the location(s) to which we'll write to in our dynamically changing Metal buffers for
    //   the current frame (i.e. update our slot in the ring buffer used for the current frame)
    
    _uniformBufferIndex = (_uniformBufferIndex + 1) % kMaxBuffersInFlight;
    
    _sharedUniformBufferOffset = kAlignedSharedUniformsSize * _uniformBufferIndex;
    _anchorUniformBufferOffset = kAlignedInstanceUniformsSize * _uniformBufferIndex;
    
    _sharedUniformBufferAddress = ((uint8_t*)_sharedUniformBuffer) + _sharedUniformBufferOffset;
    _anchorUniformBufferAddress = ((uint8_t*)_anchorUniformBuffer) + _anchorUniformBufferOffset;
}

- (void)_updateSharedUniformsWithFrame:(ARFrame *)frame {
    // Update the shared uniforms of the frame
    SharedUniforms *uniforms = (SharedUniforms *)_sharedUniformBufferAddress;
    
    uniforms->viewMatrix = [frame.camera viewMatrixForOrientation:UIInterfaceOrientationPortrait];
    uniforms->projectionMatrix = [frame.camera projectionMatrixForOrientation:UIInterfaceOrientationPortrait
                                                                 viewportSize:_sceneSize
                                                                        zNear:0.001
                                                                         zFar:1000];
    
    // Set up lighting for the scene using the ambient intensity if provided
    float ambientIntensity = 1.0;
    
    if (frame.lightEstimate) {
        ambientIntensity = frame.lightEstimate.ambientIntensity / 1000;
    }
    
    vector_float3 ambientLightColor = { 0.5, 0.5, 0.5 };
    uniforms->ambientLightColor = ambientLightColor * ambientIntensity;
    
    vector_float3 directionalLightDirection = { 0.0, 0.0, -1.0 };
    directionalLightDirection = vector_normalize(directionalLightDirection);
    uniforms->directionalLightDirection = directionalLightDirection;
    
    vector_float3 directionalLightColor = { 0.6, 0.6, 0.6};
    uniforms->directionalLightColor = directionalLightColor * ambientIntensity;
    
    uniforms->materialShininess = 30;
}

- (void)_updateAnchorsWithFrame:(ARFrame *)frame {
    // Update the anchor uniform buffer with transforms of the current frame's anchors
    NSInteger anchorInstanceCount = MIN(frame.anchors.count, kMaxAnchorInstanceCount);
    
    NSInteger anchorOffset = 0;
    if (anchorInstanceCount == kMaxAnchorInstanceCount) {
        anchorOffset = MAX(frame.anchors.count - kMaxAnchorInstanceCount, 0);
    }
  
    _anchorCenter[0] = 0;
    _anchorCenter[1] = 0;
    _anchorCenter[2] = 0;
    for (NSInteger index = 0; index < anchorInstanceCount; index++) {
        InstanceUniforms *anchorUniforms = ((InstanceUniforms *)_anchorUniformBufferAddress) + index;
        ARAnchor *anchor = frame.anchors[index + anchorOffset];
        
        // Flip Z axis to convert geometry from right handed to left handed
        matrix_float4x4 coordinateSpaceTransform = matrix_identity_float4x4;
        coordinateSpaceTransform.columns[2].z = -1.0;
        
        anchorUniforms->modelMatrix = matrix_multiply(anchor.transform, coordinateSpaceTransform);
      
        if (index == (anchorInstanceCount - 1)) {
          _anchorCenter[0] = anchor.transform.columns[3].x;
          _anchorCenter[1] = anchor.transform.columns[3].y;
          _anchorCenter[2] = anchor.transform.columns[3].z;
        }
    }
    
    _anchorInstanceCount = anchorInstanceCount;
}

- (void)_updateGameState:(ARFrame *)frame {
    [self _updateSharedUniformsWithFrame:frame];
    [self _updateAnchorsWithFrame:frame];
}

- (void)_drawAnchorGeometry
{
    SharedUniforms *uniforms = (SharedUniforms *)_sharedUniformBufferAddress;
    float viewmtx[] = {
      uniforms->projectionMatrix.columns[0][0],
      uniforms->projectionMatrix.columns[0][1],
      uniforms->projectionMatrix.columns[0][2],
      uniforms->projectionMatrix.columns[0][3],
      uniforms->projectionMatrix.columns[1][0],
      uniforms->projectionMatrix.columns[1][1],
      uniforms->projectionMatrix.columns[1][2],
      uniforms->projectionMatrix.columns[1][3],
      uniforms->projectionMatrix.columns[2][0],
      uniforms->projectionMatrix.columns[2][1],
      uniforms->projectionMatrix.columns[2][2],
      uniforms->projectionMatrix.columns[2][3],
      uniforms->projectionMatrix.columns[3][0],
      uniforms->projectionMatrix.columns[3][1],
      uniforms->projectionMatrix.columns[3][2],
      uniforms->projectionMatrix.columns[3][3],
    };
    float projmtx[] = {
      uniforms->viewMatrix.columns[0][0],
      uniforms->viewMatrix.columns[0][1],
      uniforms->viewMatrix.columns[0][2],
      uniforms->viewMatrix.columns[0][3],
      uniforms->viewMatrix.columns[1][0],
      uniforms->viewMatrix.columns[1][1],
      uniforms->viewMatrix.columns[1][2],
      uniforms->viewMatrix.columns[1][3],
      uniforms->viewMatrix.columns[2][0],
      uniforms->viewMatrix.columns[2][1],
      uniforms->viewMatrix.columns[2][2],
      uniforms->viewMatrix.columns[2][3],
      uniforms->viewMatrix.columns[3][0],
      uniforms->viewMatrix.columns[3][1],
      uniforms->viewMatrix.columns[3][2],
      uniforms->viewMatrix.columns[3][3],
    };
    float centerArray[] = {
      _anchorCenter[0],
      _anchorCenter[1],
      _anchorCenter[2],
    };
    NodeService_onDrawFrame(viewmtx, projmtx, centerArray);
}

#pragma mark Delegate

- (void)glkView:(GLKView *)view drawInRect:(CGRect)rect
{    
    _sceneSize = view.frame.size;
    [view bindDrawable];
    // [self _updateBufferStates];
    // [self _updateGameState:frame];
    // [self drawCameraFrame:frame];
    // [self _drawAnchorGeometry];
  
    printf("node frame\n");
  
    long now = CFAbsoluteTimeGetCurrent() * 1000;
    int timeout = (int)MIN(MAX(FRAME_TIME_MAX - (now - lastFrameTime), FRAME_TIME_MIN), FRAME_TIME_MAX);
    lastFrameTime = now;
    NodeService_tick(timeout);
}

@end

