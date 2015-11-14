/*
 
 Copyright (c) 2011 David Petrie david@davidpetrie.com
 
 This software is provided 'as-is', without any express or implied warranty.
 In no event will the authors be held liable for any damages arising from the 
 use of this software. Permission is granted to anyone to use this software for
 any purpose, including commercial applications, and to alter it and 
 redistribute it freely, subject to the following restrictions:
 
 1. The origin of this software must not be misrepresented; you must not claim 
 that you wrote the original software. If you use this software in a product, an 
 acknowledgment in the product documentation would be appreciated but is not 
 required.
 2. Altered source versions must be plainly marked as such, and must not be 
 misrepresented as being the original software.
 3. This notice may not be removed or altered from any source distribution.
 
 */

#import "GLESViewController.h"
#import "TextureLoader.h"

#define FRAME_BUFFER_TEX_SIZE 256

@interface GLESViewController ()
@property (strong, nonatomic) EAGLContext *context;
- (void)setupGL;
- (void)tearDownGL;
@end

@interface GLESViewController (PrivateMethods)
- (void) genTextureFrameBuf;
- (void) render;
- (void) renderImage:(GLuint)handle size:(float)size;
- (void) ShowFPS;
@end


@implementation GLESViewController

static pixel_t * glowData = NULL;

- (void)viewDidLoad {
    [super viewDidLoad];

    self.context = [[[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES1] autorelease];

    if (!self.context) {
        NSLog(@"Failed to create ES context");
    }

    GLKView *view = (GLKView *)self.view;
    view.context = self.context;
    view.drawableDepthFormat = GLKViewDrawableDepthFormat24;
    [view  setMultipleTouchEnabled:YES];

    self.preferredFramesPerSecond = 60;

    animating = FALSE;
    displayLink = nil;
    animationFrameInterval = 1;
    animationTimer = nil;

    [self setupGL];
}


- (void) viewWillAppear:(BOOL)animated {
    LoadTexture("transparent.png", &textureHandle);
    [self genTextureFrameBuf];

    // Glow:
    CGImageRef img = [UIImage imageNamed:[NSString stringWithUTF8String:"point_glow_s.png"]].CGImage;
    size_t width = CGImageGetWidth(img);
    size_t height = CGImageGetHeight(img);

    if (img) {
        glowData = (pixel_t *)calloc(1, width * height * sizeof(pixel_t));
        CGContextRef context = CGBitmapContextCreate(glowData, width, height, 8, width * 4,
                                                     CGImageGetColorSpace(img),
                                                     kCGImageAlphaPremultipliedLast);
        CGContextDrawImage(context, CGRectMake(0.0, 0.0, (CGFloat)width, (CGFloat)height), img);
        CGContextRelease(context);
    }

    [super viewWillAppear:animated];
}


- (void)viewDidUnload {
    [super viewDidUnload];

    [self tearDownGL];

    if ([EAGLContext currentContext] == self.context) {
        [EAGLContext setCurrentContext:nil];
    }
    self.context = nil;
}


- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return (interfaceOrientation == UIInterfaceOrientationLandscapeLeft ||
            interfaceOrientation == UIInterfaceOrientationLandscapeRight);
}


- (void)setupGL {
    [EAGLContext setCurrentContext:self.context];

    glEnable(GL_LINE_SMOOTH);
    glLineWidth(1.0f);
    glClearColor(1.0f, 1.0f, 1.0f, 1.0f);
}


- (void)tearDownGL {
    [EAGLContext setCurrentContext:self.context];
}


- (void) genTextureFrameBuf {
    GLint oldFrameBuffer;
    GLuint stat;
    
    GLubyte *data = (GLubyte *)calloc(1, FRAME_BUFFER_TEX_SIZE * FRAME_BUFFER_TEX_SIZE * 4);
    glGenTextures(1,  &hiddenFboTextureHandle);
    glBindTexture(GL_TEXTURE_2D, hiddenFboTextureHandle);		
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, FRAME_BUFFER_TEX_SIZE, FRAME_BUFFER_TEX_SIZE, 0, GL_RGBA, GL_UNSIGNED_BYTE, data);
    glGenerateMipmapOES(GL_TEXTURE_2D);
    free(data);
    
    glGetIntegerv(GL_FRAMEBUFFER_BINDING_OES, &oldFrameBuffer);
	glGenFramebuffersOES(1, &hiddenFboHandle);
	glBindFramebufferOES(GL_FRAMEBUFFER_OES, hiddenFboHandle);
    glFramebufferTexture2DOES(GL_FRAMEBUFFER_OES, GL_COLOR_ATTACHMENT0_OES, GL_TEXTURE_2D, hiddenFboTextureHandle, 0);
	if ((stat = glCheckFramebufferStatusOES(GL_FRAMEBUFFER_OES)) != GL_FRAMEBUFFER_COMPLETE_OES) {
		printf("FBO bad status %x.\n", stat);
    }
    glBindFramebufferOES(GL_FRAMEBUFFER_OES, oldFrameBuffer);
}


/**
 * When generating each square value, we treat pixels in the following way:
 * A B
 * C D
 *
 * These are then combined into an GLubyte if the alpha value exceeds a 
 * certain threshold, like this: 0000ABCD
 */

static pixel_t * inputPixels = NULL;
static pixel_t * outputPixels = NULL;
const GLubyte kAlphaThreshold = 0;

- (void)marchingSquares {
    GLint oldfb;
    GLfloat vp[4];
 
    if (!inputPixels) {
        inputPixels = (pixel_t *)calloc(1, sizeof(pixel_t) * FRAME_BUFFER_TEX_SIZE * FRAME_BUFFER_TEX_SIZE);
    }
    
    if (!outputPixels) {
        outputPixels = (pixel_t *)calloc(1, sizeof(pixel_t) * FRAME_BUFFER_TEX_SIZE * FRAME_BUFFER_TEX_SIZE); 
    }
    
    glGetFloatv(GL_VIEWPORT, vp);
    glGetIntegerv(GL_FRAMEBUFFER_BINDING_OES, &oldfb);
    glBindFramebufferOES(GL_FRAMEBUFFER_OES, hiddenFboTextureHandle);
    
	glViewport(0.0f, 0.0f, FRAME_BUFFER_TEX_SIZE, FRAME_BUFFER_TEX_SIZE * (self.view.frame.size.height/self.view.frame.size.width));
    glClearColor(1.0f, 1.0f, 1.0f, 0.0f);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    
    glMatrixMode(GL_PROJECTION);
    glLoadIdentity();
    glOrthof(0.0f, self.view.frame.size.width, 0.0f, self.view.frame.size.height,  -10000.0f, 10000.0f);
    
	glMatrixMode(GL_MODELVIEW);
	glLoadIdentity();
    
    glEnable(GL_TEXTURE_2D);
    glEnable(GL_BLEND);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    
    aglColor4f(1.0f, 1.0f, 1.0f, 1.0f);
    [self renderImage:textureHandle size:FRAME_BUFFER_TEX_SIZE];

    glReadPixels(0, 0, FRAME_BUFFER_TEX_SIZE, FRAME_BUFFER_TEX_SIZE, GL_RGBA, GL_UNSIGNED_BYTE, inputPixels);
        
    // Find a starting point
    static vec2_t startingPoint;
    static GLubyte p = 0;
    vec2Set(startingPoint, 0, 0);
    for (int i = 0; i < FRAME_BUFFER_TEX_SIZE - 1; ++i) {
        for (int j = 0; j < FRAME_BUFFER_TEX_SIZE - 1; ++j) {
            int pos = (i * FRAME_BUFFER_TEX_SIZE) + j;
            GLubyte a = inputPixels[pos][3];
            GLubyte b = inputPixels[pos+1][3];
            GLubyte c = inputPixels[pos + FRAME_BUFFER_TEX_SIZE][3];
            GLubyte d = inputPixels[pos + FRAME_BUFFER_TEX_SIZE + 1][3];
            
            p = ((a > kAlphaThreshold) << 3) + ((b > kAlphaThreshold) << 2) +((c > kAlphaThreshold) << 1) + (d > kAlphaThreshold);
            if (p > 0) {
                vec2Set(startingPoint, j, i);
                break;
            }
        }
        
        if (startingPoint[0] > 0) {
            break;
        }
    }
    
    // Generate the outline
   // bzero(outputPixels, sizeof(pixel_t) * FRAME_BUFFER_TEX_SIZE * FRAME_BUFFER_TEX_SIZE);
    
    vec2_t next;
    vec2Set(next, startingPoint[0], startingPoint[1]);
    marchNext(p, &next);
    
    while (next[0] != startingPoint[0] || next[1] != startingPoint[1]) {
        if (next[0] < 0 || next[1] < 0 || next[0] > FRAME_BUFFER_TEX_SIZE || next[1] > FRAME_BUFFER_TEX_SIZE) {
            break;
        }
        
        int pos = next[0] + (next[1] * FRAME_BUFFER_TEX_SIZE);
        
        //pixelSet(outputPixels[pos-1],   255,255,255,255);
        pixelSet(outputPixels[pos],     255,255,255,255);
        pixelSet(outputPixels[pos+1],   255,255,255,153);
        //pixelSet(outputPixels[pos + FRAME_BUFFER_TEX_SIZE - 1], 255,255,255,255);
        pixelSet(outputPixels[pos + FRAME_BUFFER_TEX_SIZE],     255,255,255,153);
        pixelSet(outputPixels[pos + FRAME_BUFFER_TEX_SIZE + 1], 255,255,255,153);
        //pixelSet(outputPixels[pos - FRAME_BUFFER_TEX_SIZE - 1], 255,255,255,255);
        pixelSet(outputPixels[pos - FRAME_BUFFER_TEX_SIZE],     255,255,255,153);
        pixelSet(outputPixels[pos - FRAME_BUFFER_TEX_SIZE + 1], 255,255,255,153);
        
        GLubyte a = inputPixels[pos][3];
        GLubyte b = inputPixels[pos+1][3];
        GLubyte c = inputPixels[pos + FRAME_BUFFER_TEX_SIZE][3];
        GLubyte d = inputPixels[pos + FRAME_BUFFER_TEX_SIZE + 1][3];
        
        p = ((a > kAlphaThreshold) << 3) + ((b > kAlphaThreshold) << 2) +((c > kAlphaThreshold) << 1) + (d > kAlphaThreshold);
        
        if (p == 0) {
            break;
        }
        
        marchNext(p, &next);
    }

    glBindTexture(GL_TEXTURE_2D, hiddenFboTextureHandle);
    glTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0, FRAME_BUFFER_TEX_SIZE, FRAME_BUFFER_TEX_SIZE, GL_RGBA, GL_UNSIGNED_BYTE, outputPixels);
    
    glBindFramebufferOES(GL_FRAMEBUFFER_OES, oldfb);
    glViewport(0,0, vp[2], vp[3]);
}


void marchNext(GLubyte val, vec2_t * vec) {
    // Marching squares:
    // 1100 12 ->
    // 0011 3  <-
    // 1110 14 ->
    // 0100 4  ->
    // 1000 8  ^
    // 1011 11 ^
    // 1001 9  ^
    // 0101 5  v
    // 1010 10 ^
    // 0111 7  <-
    // 0110 6  <-
    // 0001 1  v
    // 0010 2  <-
    // 1101 13 v
    // 1111 15 _

    if (val == 1 || val == 5 || val == 13) {
        // Down
        (*vec)[1] += 1;
    } else if (val == 2 || val == 3 || val == 6 || val == 7) {
        // Left
        (*vec)[0] -= 1;
    } else if (val >= 8 && val <= 11) {
        // In our case, the index is lower as you go up
        (*vec)[1] -= 1;
    } else if (val == 4 || val == 12 || val == 14) {
        (*vec)[0] += 1;
    }
}


static float zMove = 0.0f;
static float rot = 0.0f;

- (void)render {
    glClearColor(0.5f, 0.5f, 0.5f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT);
    
    [self marchingSquares];
    
    glMatrixMode(GL_PROJECTION);
    glLoadIdentity();
    glOrthof(0.0f, self.view.frame.size.width, 0.0f, self.view.frame.size.height,  -10000.0f, 10000.0f);

    glMatrixMode(GL_MODELVIEW);
    glEnable(GL_TEXTURE_2D);
    
    glEnable(GL_BLEND);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    
    glPushMatrix();
    glRotatef(rot, 0.0f, 0.0f, 1.0f);
    [self renderImage:hiddenFboTextureHandle size:self.view.frame.size.width];
    //[self renderImage:textureHandle size:FRAME_BUFFER_TEX_SIZE];
	glPopMatrix();
    
    rot += 0.1f;
}


- (void) renderImage:(GLuint)handle size:(float)size {
    glBindTexture(GL_TEXTURE_2D, handle);

	aglBegin(GL_TRIANGLE_STRIP);
	
    aglTexCoord2f(0.0f, 0.0f);
	aglColor4f(1.0f, 1.0f, 1.0f, 1.0f);
    aglVertex3f(0.0f, 0.0f, 0.0f);
    
	aglTexCoord2f(1.0f, 0.0f);
    aglColor4f(1.0f, 1.0f, 1.0f, 1.0f);
	aglVertex3f(size, 0.0f, 0.0f);
    
    aglTexCoord2f(0.0f, 1.0f);
	aglColor4f(1.0f, 1.0f, 1.0f, 1.0f);
    aglVertex3f(0.0f, size, 0.0f);
    
    aglTexCoord2f(1.0f, 1.0f);
	aglColor4f(1.0f, 1.0f, 1.0f, 1.0f);
    aglVertex3f(size, size, 0.0f);
    
	aglEnd();
}


#pragma mark - GLKView and GLKViewController delegate methods

- (void)update {
    ++frames;
    CurrentTime = CACurrentMediaTime();

    if ((CurrentTime - LastFPSUpdate) > 1.0f) {
        printf("fps: %d\n", frames);
        frames = 0;
        LastFPSUpdate = CurrentTime;
    }
}


- (void)glkView:(GLKView *)view drawInRect:(CGRect)rect {
    [self render];
}


- (void)dealloc {
    [self.view release];
    [super dealloc];
}

@end
