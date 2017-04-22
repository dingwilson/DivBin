#ifdef __OBJC__
#import <UIKit/UIKit.h>
#else
#ifndef FOUNDATION_EXPORT
#if defined(__cplusplus)
#define FOUNDATION_EXPORT extern "C"
#else
#define FOUNDATION_EXPORT extern
#endif
#endif
#endif

#import "ClarifaiApp.h"
#import "ClarifaiConcept.h"
#import "ClarifaiConstants.h"
#import "ClarifaiCrop.h"
#import "ClarifaiImage.h"
#import "ClarifaiInput.h"
#import "ClarifaiModel.h"
#import "ClarifaiModelVersion.h"
#import "ClarifaiOutput.h"
#import "ClarifaiSearchResult.h"
#import "ClarifaiSearchTerm.h"
#import "NSArray+Clarifai.h"

FOUNDATION_EXPORT double ClarifaiVersionNumber;
FOUNDATION_EXPORT const unsigned char ClarifaiVersionString[];

