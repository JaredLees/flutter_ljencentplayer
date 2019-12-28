#import "FlutterLjencentplayerPlugin.h"
#import <flutter_ljencentplayer/flutter_ljencentplayer-Swift.h>

@implementation FlutterLjencentplayerPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  [SwiftFlutterLjencentplayerPlugin registerWithRegistrar:registrar];
}
@end
