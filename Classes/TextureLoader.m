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

#import "TextureLoader.h"
#import <UIKit/UIKit.h>

extern void LoadTexture(const char *filename, GLuint *handle) {
    CGImageRef img = [UIImage imageNamed:[NSString stringWithUTF8String:filename]].CGImage;
    unsigned long width = CGImageGetWidth(img);
    unsigned long height = CGImageGetHeight(img);

    if (img) {
        GLubyte *data = (GLubyte *)calloc(1, width * height * 4);
        CGContextRef context = CGBitmapContextCreate(data, width, height, 8, width * 4,
                                                     CGImageGetColorSpace(img),
                                                     kCGImageAlphaPremultipliedLast);
        CGContextDrawImage(context, CGRectMake(0.0, 0.0, (CGFloat)width, (CGFloat)height), img);
        CGContextRelease(context);
        glGenTextures(1, handle);
        glBindTexture(GL_TEXTURE_2D, *handle);
        glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, width, height, 0, GL_RGBA, GL_UNSIGNED_BYTE, data);
        glGenerateMipmapOES(GL_TEXTURE_2D);
        free(data);
    }
}