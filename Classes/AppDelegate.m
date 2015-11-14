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


#import "AppDelegate.h"
#import "GLESViewController.h"

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    CGRect	rect = [[UIScreen mainScreen] bounds];
    window = [[UIWindow alloc] initWithFrame:rect];

    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
        glViewController = [[[GLESViewController alloc] initWithNibName:@"ViewController_iPhone" bundle:nil] autorelease];
    } else {
        glViewController = [[[GLESViewController alloc] initWithNibName:@"ViewController_iPad" bundle:nil] autorelease];
    }

    [window setRootViewController:glViewController];
    [window makeKeyAndVisible];

    [glViewController startAnimation];

    return YES;
}


- (void)applicationWillResignActive:(UIApplication *)application {
    [glViewController stopAnimation];
}


- (void)applicationDidBecomeActive:(UIApplication *)application {
    [glViewController startAnimation];
}


- (void)applicationWillTerminate:(UIApplication *)application {
    [glViewController stopAnimation];
}


- (void)dealloc {
    [window release];
    [glViewController release];

    [super dealloc];
}

@end
