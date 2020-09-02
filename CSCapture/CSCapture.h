#import <Foundation/Foundation.h>



//! Project version number for CSCapture.
FOUNDATION_EXPORT double CSCaptureVersionNumber;

//! Project version string for CSCapture.
FOUNDATION_EXPORT const unsigned char CSCaptureVersionString[];



@interface CSCapture : NSObject
- (NSData *)binaryCodesignBlob;

@end
