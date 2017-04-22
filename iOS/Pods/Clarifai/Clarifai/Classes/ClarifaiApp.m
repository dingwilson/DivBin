//
//  ClarifaiApp.m
//  ClarifaiApiDemo
//
//  Created by John Sloan on 9/1/16.
//  Copyright © 2016 Clarifai, Inc. All rights reserved.
//

#import "ClarifaiApp.h"
#import "NSArray+Clarifai.h"
#import "ClarifaiSearchResult.h"

/** OAuth access token response. */
@interface ClarifaiAccessTokenResponse : NSObject
@property (strong, nonatomic) NSString *accessToken;
@property (assign, nonatomic) NSTimeInterval expiresIn;
@end

@implementation ClarifaiAccessTokenResponse

- (instancetype)initWithDictionary:(NSDictionary *)dict {
  self = [super init];
  if (self) {
    _accessToken = dict[@"access_token"];
    _expiresIn = MAX([dict[@"expires_in"] doubleValue], kMinTokenLifetime);
  }
  return self;
}

@end

@interface ClarifaiApp ()

@property (assign, nonatomic) BOOL authenticating;
@property (strong, nonatomic) NSString *appID;
@property (strong, nonatomic) NSString *appSecret;
@property (strong, nonatomic) NSDate *accessTokenExpiration;
@property (strong, nonatomic) NSDictionary *predictionTypes;
@property (strong, nonatomic) NSDictionary *modelTypes;

@end

@implementation ClarifaiApp

- (instancetype)initWithAppID:(NSString *)appID appSecret:(NSString *)appSecret {
  self = [super init];
  if (self) {
    _appID = appID;
    _appSecret = appSecret;
    
    // Configure AFNetworking:
    _sessionManager = [AFHTTPSessionManager manager];
    _sessionManager.operationQueue.maxConcurrentOperationCount = 4;
    _sessionManager.completionQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    _sessionManager.requestSerializer = [AFJSONRequestSerializer serializer];
    _sessionManager.requestSerializer.HTTPMethodsEncodingParametersInURI = [NSSet setWithObjects:@"GET", @"HEAD", nil];
    [_sessionManager.requestSerializer setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    _sessionManager.responseSerializer = [AFJSONResponseSerializer serializer];
    _sessionManager.responseSerializer.acceptableContentTypes = [[NSSet alloc] initWithArray:@[@"application/json"]]; 
    
    _modelTypes = @{
                    @(ClarifaiModelTypeEmbed): @"embed",
                    @(ClarifaiModelTypeConcept): @"concept",
                    @(ClarifaiModelTypeDetection): @"detection",
                    @(ClarifaiModelTypeCluster): @"cluster",
                    @(ClarifaiModelTypeColor): @"color"
                    };
    
    [self loadAccessToken];
  }
  return self;
}

#pragma mark - inputs

- (void)addInputs:(NSArray <ClarifaiInput *> *)inputs completion:(ClarifaiInputsCompletion)completion {
  [self ensureValidAccessToken:^(NSError *error) {
    if (error) {
      SafeRunBlock(completion, nil, error);
      return;
    }
    if ([inputs count] > 128) {
      NSError *error = [[NSError alloc] initWithDomain:kErrorDomain code:400 userInfo:@{@"description": @"Cannot add more than 128 inputs at a time."}];
      completion(nil,error);
      return;
    }
    NSString *apiURL = [kApiBaseUrl stringByAppendingString:@"/inputs"];
    NSMutableArray *inputsArray = [NSMutableArray array];
    for (int i = 0; i < inputs.count; i++) {
      ClarifaiInput *input = inputs[i];
      
      NSMutableDictionary *inputEntry = [NSMutableDictionary dictionary];
      
      // set inputID if one was provided
      if (![input.inputID isEqual: @""] && input.inputID != nil) {
        inputEntry[@"id"] = input.inputID;
      }
      
      // set data dict (contains image and tags).
      NSMutableDictionary *data = [NSMutableDictionary dictionary];
      
      // add url or imageData to image dict.
      NSMutableDictionary *image = [NSMutableDictionary dictionary];
      if (![input.mediaURL isEqual: @""] && input.mediaURL != nil) {
        // input has url
        image[@"url"] = input.mediaURL;
        image[@"allow_duplicate_url"] = input.allowDuplicateURLs ? @YES : @NO;
      } else if (input.mediaData != nil) {
        // input has image data
        NSString *encodedString = [input.mediaData base64EncodedStringWithOptions:NSDataBase64Encoding64CharacterLineLength];
        image[@"base64"] = encodedString;
      }

      if ([input isKindOfClass:[ClarifaiImage class]]) {
        // add crop, if exists, to image dict.
        if (((ClarifaiImage *)input).crop != nil) {
          [image setObject:@[ @(((ClarifaiImage *)input).crop.top),
                              @(((ClarifaiImage *)input).crop.left),
                              @(((ClarifaiImage *)input).crop.bottom),
                              @(((ClarifaiImage *)input).crop.right) ] forKey:@"crop"];
        }
      }
      data[@"image"] = image;
      
      // add concepts to data dict.
      if (input.concepts != nil && input.concepts.count != 0) {
        NSMutableArray *concepts = [NSMutableArray array];
        // init concepts
        for (ClarifaiConcept *concept in input.concepts) {
          NSMutableDictionary *conceptDict = [NSMutableDictionary dictionary];
          conceptDict[@"id"] = concept.conceptID;
          if (concept.conceptName) {
            conceptDict[@"name"] = concept.conceptName;
          }
          // can only be true or false when adding concepts with inputs.
          conceptDict[@"value"] = concept.score > 0 ? [NSNumber numberWithInt:1] : [NSNumber numberWithInt:0];
          [concepts addObject:conceptDict];
        }
        data[@"concepts"] = concepts;
      }
      
      // add metadata, if any.
      if (input.metadata != nil) {
        data[@"metadata"] = input.metadata;
      }
      
      inputEntry[@"data"] = data;
      [inputsArray addObject:inputEntry];
    }
      
    NSDictionary *params = @{ @"inputs": inputsArray };
    
    [_sessionManager POST:apiURL
               parameters:params
                 progress:nil
                  success:^(NSURLSessionDataTask *task, id response) {
                    NSMutableArray *inputs = [NSMutableArray array];
                    NSArray *inputsResponse = response[@"inputs"];
                    for (NSDictionary *inputEntry in inputsResponse) {
                      [inputs addObject:[[ClarifaiInput alloc] initWithDictionary:inputEntry]];
                    }
                    completion(inputs, nil);
                  } failure:^(NSURLSessionDataTask *task, NSError *error) {
                    completion(nil, error);
                  }];
  }];
}

- (void)mergeConcepts:(NSArray <ClarifaiConcept *> *)concepts forInputWithID:(NSString *)inputID completion:(ClarifaiStoreInputCompletion)completion {
  [self ensureValidAccessToken:^(NSError *error) {
    if (error) {
      SafeRunBlock(completion, nil, error);
      return;
    }
    
    NSMutableDictionary *inputDict = [NSMutableDictionary dictionary];
    inputDict[@"id"] = inputID;
    
    // create concepts array
    NSMutableDictionary *data = [NSMutableDictionary dictionary];
    NSMutableArray *conceptsArray = [NSMutableArray array];
    for (ClarifaiConcept *concept in concepts) {
      NSMutableDictionary *conceptDict = [NSMutableDictionary dictionary];
      conceptDict[@"id"] = concept.conceptID;
      conceptDict[@"value"] = [NSNumber numberWithFloat:concept.score];
      [conceptsArray addObject:conceptDict];
    }
    
    data[@"concepts"] = conceptsArray;
    inputDict[@"data"] = data;
    
    NSMutableDictionary *params = [NSMutableDictionary dictionary];
    params[@"inputs"] = @[inputDict];
    params[@"action"] = @"merge";
    
    NSString *inputURLSuffix = [NSString stringWithFormat:@"/inputs/"];
    NSString *apiURL = [kApiBaseUrl stringByAppendingString:inputURLSuffix];
    
    [_sessionManager PATCH:apiURL
                parameters:params
                   success:^(NSURLSessionDataTask *task, id response) {
      ClarifaiInput *input = [[ClarifaiInput alloc] initWithDictionary:response[@"inputs"][0]];
      completion(input, nil);
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
      completion(nil, error);
    }];
  }];
}

- (void)mergeConceptsForInputs:(NSArray<ClarifaiInput *> *)inputs completion:(ClarifaiInputsCompletion)completion {
  [self ensureValidAccessToken:^(NSError *error) {
    if (error) {
      SafeRunBlock(completion, nil, error);
      return;
    }
    NSMutableArray *inputsArray = [[NSMutableArray alloc] init];
    for (ClarifaiInput *input in inputs) {
      NSMutableDictionary *inputDict = [NSMutableDictionary dictionary];
      inputDict[@"id"] = input.inputID;
      
      // create concepts array
      NSMutableDictionary *data = [NSMutableDictionary dictionary];
      NSMutableArray *conceptsArray = [NSMutableArray array];
      for (ClarifaiConcept *concept in input.concepts) {
        NSMutableDictionary *conceptDict = [NSMutableDictionary dictionary];
        conceptDict[@"id"] = concept.conceptID;
        conceptDict[@"value"] = [NSNumber numberWithFloat:concept.score];
        [conceptsArray addObject:conceptDict];
      }
      
      data[@"concepts"] = conceptsArray;
      inputDict[@"data"] = data;
      [inputsArray addObject:inputDict];
    }
    
    NSMutableDictionary *params = [NSMutableDictionary dictionary];
    params[@"inputs"] = inputsArray;
    params[@"action"] = @"merge";
    
    NSString *inputURLSuffix = [NSString stringWithFormat:@"/inputs/"];
    NSString *apiURL = [kApiBaseUrl stringByAppendingString:inputURLSuffix];
    
    [_sessionManager PATCH:apiURL
                parameters:params
                   success:^(NSURLSessionDataTask *task, id response) {
      NSMutableArray *inputs = [[NSMutableArray alloc] init];
      for (NSDictionary *inputDict in response[@"inputs"]) {
        ClarifaiInput *input = [[ClarifaiInput alloc] initWithDictionary:inputDict];
        [inputs addObject:input];
      }
      completion(inputs, nil);
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
      completion(nil, error);
    }];
  }];
}

- (void)setConcepts:(NSArray <ClarifaiConcept *> *)concepts forInputWithID:(NSString *)inputID completion:(ClarifaiStoreInputCompletion)completion {
    [self ensureValidAccessToken:^(NSError *error) {
        if (error) {
            SafeRunBlock(completion, nil, error);
            return;
        }
        
        NSMutableDictionary *inputDict = [NSMutableDictionary dictionary];
        inputDict[@"id"] = inputID;
        
        // create concepts array
        NSMutableDictionary *data = [NSMutableDictionary dictionary];
        NSMutableArray *conceptsArray = [NSMutableArray array];
        for (ClarifaiConcept *concept in concepts) {
            NSMutableDictionary *conceptDict = [NSMutableDictionary dictionary];
            conceptDict[@"id"] = concept.conceptID;
            conceptDict[@"value"] = [NSNumber numberWithFloat:concept.score];
            [conceptsArray addObject:conceptDict];
        }
        
        data[@"concepts"] = conceptsArray;
        inputDict[@"data"] = data;
        
        NSMutableDictionary *params = [NSMutableDictionary dictionary];
        params[@"inputs"] = @[inputDict];
        params[@"action"] = @"overwrite";
        
        NSString *inputURLSuffix = [NSString stringWithFormat:@"/inputs/"];
        NSString *apiURL = [kApiBaseUrl stringByAppendingString:inputURLSuffix];
      
        [_sessionManager PATCH:apiURL
                    parameters:params
                       success:^(NSURLSessionDataTask *task, id response) {
          ClarifaiInput *input = [[ClarifaiInput alloc] initWithDictionary:response[@"inputs"][0]];
          completion(input, nil);
        } failure:^(NSURLSessionDataTask *task, NSError *error) {
          completion(nil, error);
        }];
    }];
}

- (void)setConceptsForInputs:(NSArray<ClarifaiInput *> *)inputs completion:(ClarifaiInputsCompletion)completion {
    [self ensureValidAccessToken:^(NSError *error) {
        if (error) {
            SafeRunBlock(completion, nil, error);
            return;
        }
        NSMutableArray *inputsArray = [[NSMutableArray alloc] init];
        for (ClarifaiInput *input in inputs) {
            NSMutableDictionary *inputDict = [NSMutableDictionary dictionary];
            inputDict[@"id"] = input.inputID;
            
            // create concepts array
            NSMutableDictionary *data = [NSMutableDictionary dictionary];
            NSMutableArray *conceptsArray = [NSMutableArray array];
            for (ClarifaiConcept *concept in input.concepts) {
                NSMutableDictionary *conceptDict = [NSMutableDictionary dictionary];
                conceptDict[@"id"] = concept.conceptID;
                conceptDict[@"value"] = [NSNumber numberWithFloat:concept.score];
                [conceptsArray addObject:conceptDict];
            }
            
            data[@"concepts"] = conceptsArray;
            inputDict[@"data"] = data;
            [inputsArray addObject:inputDict];
        }
        
        NSMutableDictionary *params = [NSMutableDictionary dictionary];
        params[@"inputs"] = inputsArray;
        params[@"action"] = @"overwrite";
        
        NSString *inputURLSuffix = [NSString stringWithFormat:@"/inputs/"];
        NSString *apiURL = [kApiBaseUrl stringByAppendingString:inputURLSuffix];
      
      
        [_sessionManager PATCH:apiURL
                    parameters:params
                       success:^(NSURLSessionDataTask *task, id response) {
          NSMutableArray *inputs = [[NSMutableArray alloc] init];
          for (NSDictionary *inputDict in response[@"inputs"]) {
            ClarifaiInput *input = [[ClarifaiInput alloc] initWithDictionary:inputDict];
            [inputs addObject:input];
          }
          completion(inputs, nil);
        } failure:^(NSURLSessionDataTask *task, NSError *error) {
          completion(nil, error);
        }];
    }];
}

- (void)deleteConcepts:(NSArray <ClarifaiConcept *> *)concepts forInputWithID:(NSString *)inputID completion:(ClarifaiStoreInputCompletion)completion {
  [self ensureValidAccessToken:^(NSError *error) {
    if (error) {
      SafeRunBlock(completion, nil, error);
      return;
    }
    
    NSMutableDictionary *inputDict = [NSMutableDictionary dictionary];
    inputDict[@"id"] = inputID;
    
    // create concepts array
    NSMutableDictionary *data = [NSMutableDictionary dictionary];
    NSMutableArray *conceptsArray = [NSMutableArray array];
    for (ClarifaiConcept *concept in concepts) {
      NSMutableDictionary *conceptDict = [NSMutableDictionary dictionary];
      conceptDict[@"id"] = concept.conceptID;
      [conceptsArray addObject:conceptDict];
    }
    
    data[@"concepts"] = conceptsArray;
    inputDict[@"data"] = data;
    
    NSMutableDictionary *params = [NSMutableDictionary dictionary];
    params[@"inputs"] = @[inputDict];
    params[@"action"] = @"remove";
    
    NSString *inputURLSuffix = [NSString stringWithFormat:@"/inputs/"];
    NSString *apiURL = [kApiBaseUrl stringByAppendingString:inputURLSuffix];
    
    [_sessionManager PATCH:apiURL
                parameters:params
                   success:^(NSURLSessionDataTask *task, id response) {
      ClarifaiInput *input = [[ClarifaiInput alloc] initWithDictionary:response[@"inputs"][0]];
      completion(input, nil);
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
      completion(nil, error);
    }];
  }];
}

- (void)deleteConceptsForInputs:(NSArray<ClarifaiInput *> *)inputs completion:(ClarifaiInputsCompletion)completion {
  [self ensureValidAccessToken:^(NSError *error) {
    if (error) {
      SafeRunBlock(completion, nil, error);
      return;
    }
    NSMutableArray *inputsArray = [[NSMutableArray alloc] init];
    for (ClarifaiInput *input in inputs) {
      NSMutableDictionary *inputDict = [NSMutableDictionary dictionary];
      inputDict[@"id"] = input.inputID;
      
      // create concepts array
      NSMutableDictionary *data = [NSMutableDictionary dictionary];
      NSMutableArray *conceptsArray = [NSMutableArray array];
      for (ClarifaiConcept *concept in input.concepts) {
        NSMutableDictionary *conceptDict = [NSMutableDictionary dictionary];
        conceptDict[@"id"] = concept.conceptID;
        [conceptsArray addObject:conceptDict];
      }
      
      data[@"concepts"] = conceptsArray;
      inputDict[@"data"] = data;
      [inputsArray addObject:inputDict];
    }
    
    NSMutableDictionary *params = [NSMutableDictionary dictionary];
    params[@"inputs"] = inputsArray;
    params[@"action"] = @"remove";
    
    NSString *inputURLSuffix = [NSString stringWithFormat:@"/inputs/"];
    NSString *apiURL = [kApiBaseUrl stringByAppendingString:inputURLSuffix];
    
    [_sessionManager PATCH:apiURL
                parameters:params
                   success:^(NSURLSessionDataTask *task, id response) {
      NSMutableArray *inputs = [[NSMutableArray alloc] init];
      for (NSDictionary *inputDict in response[@"inputs"]) {
        ClarifaiInput *input = [[ClarifaiInput alloc] initWithDictionary:inputDict];
        [inputs addObject:input];
      }
      completion(inputs, nil);
    } failure:^(NSURLSessionDataTask * task, NSError *error) {
      completion(nil, error);
    }];
  }];
}

- (void)getInputsOnPage:(int)page pageSize:(int)pageSize completion:(ClarifaiInputsCompletion)completion {
  [self ensureValidAccessToken:^(NSError *error) {
    if (error) {
      SafeRunBlock(completion, nil, error);
      return;
    }
    NSString *apiURL = [kApiBaseUrl stringByAppendingString:@"/inputs"];
    
    [self.sessionManager GET:apiURL parameters:@{ @"page": @(page), @"per_page": @(pageSize) } progress:nil success:^(NSURLSessionDataTask *task, id response) {
      NSMutableArray *inputs = [NSMutableArray array];
      NSArray *inputsResponse = response[@"inputs"];
      for (NSDictionary *input in inputsResponse) {
        [inputs addObject:[[ClarifaiImage alloc] initWithDictionary:input]];
      }
      completion(inputs, nil);
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
      completion(nil, error);
    }];
  }];
}

- (void)getInput:(NSString *)inputID completion:(ClarifaiStoreInputCompletion)completion {
  [self ensureValidAccessToken:^(NSError *error) {
    if (error) {
      SafeRunBlock(completion, nil, error);
      return;
    }
    NSString *inputURLSuffix = [NSString stringWithFormat:@"/inputs/%@", inputID];
    NSString *apiURL = [kApiBaseUrl stringByAppendingString:inputURLSuffix];
    
    [_sessionManager GET:apiURL
              parameters:nil
                progress:nil
                 success:^(NSURLSessionDataTask *task, id response) {
      NSDictionary *inputResponse = response[@"input"];
      ClarifaiInput *input = [[ClarifaiInput alloc] initWithDictionary:inputResponse];
      completion(input, nil);
    } failure:^(NSURLSessionDataTask *task, NSError *error) {
      completion(nil, error);
    }];
  }];
}

- (void)getInputsStatus:(ClarifaiInputsStatusCompletion)completion {
  [self ensureValidAccessToken:^(NSError *error) {
    if (error) {
      SafeRunBlock(completion, 0, 0, 0, error);
      return;
    }
    NSString *apiURL = [kApiBaseUrl stringByAppendingString:@"/inputs/status"];
    
    [_sessionManager GET:apiURL
              parameters:nil
                progress:nil
                 success:^(NSURLSessionDataTask *task, id response) {
      NSDictionary *counts = response[@"counts"];
      int processed = [counts[@"processed"] intValue];
      int toProcess = [counts[@"to_process"] intValue];
      int errors = [counts[@"errors"] intValue];
      SafeRunBlock(completion, processed, toProcess, errors, nil);
    } failure:^(NSURLSessionDataTask *task, NSError *error) {
      SafeRunBlock(completion, 0, 0, 0, nil);
    }];
  }];
}

- (void)deleteInput:(NSString *)inputID completion:(ClarifaiRequestCompletion)completion {
  [self ensureValidAccessToken:^(NSError *error) {
    if (error) {
      SafeRunBlock(completion, error);
      return;
    }
    NSString *endpoint = [NSString stringWithFormat:@"/inputs/%@", inputID];
    NSString *apiURL = [kApiBaseUrl stringByAppendingString:endpoint];
    
    [_sessionManager DELETE:apiURL
                 parameters:nil
                    success:^(NSURLSessionDataTask *task, id responseObject) {
      completion(nil);
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
      completion(error);
    }];
  }];
}

- (void)deleteAllInputs:(ClarifaiRequestCompletion)completion {
  [self ensureValidAccessToken:^(NSError *error) {
    if (error) {
      SafeRunBlock(completion, error);
      return;
    }
    NSString *endpoint = @"/inputs/";
    NSString *apiURL = [kApiBaseUrl stringByAppendingString:endpoint];
    
    [_sessionManager DELETE:apiURL
                 parameters:@{ @"delete_all": @YES }
                    success:^(NSURLSessionDataTask *task, id response) {
      completion(nil);
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
      completion(error);
    }];
  }];
}

- (void)deleteInputsByIDList:(NSArray *)inputs completion:(ClarifaiRequestCompletion)completion {
  [self ensureValidAccessToken:^(NSError *error) {
    if (error) {
      SafeRunBlock(completion, error);
      return;
    }

    NSMutableArray *inputsArray = [NSMutableArray array];
    for (id input in inputs) {
      if ([input isKindOfClass:[NSString class]]) {
        [inputsArray addObject:input];
      } else if ([input isKindOfClass:[ClarifaiInput class]]) {
        [inputsArray addObject:((ClarifaiInput *)input).inputID];
      }
    }
    
    NSMutableDictionary *params = [NSMutableDictionary dictionary];
    params[@"ids"] = inputsArray;
    
    NSString *inputURLSuffix = @"/inputs/";
    NSString *apiURL = [kApiBaseUrl stringByAppendingString:inputURLSuffix];
    
    [_sessionManager DELETE:apiURL
                 parameters:params
                    success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable response) {
      completion(nil);
    } failure:^(NSURLSessionDataTask *task, NSError *error) {
      completion(error);
    }];
  }];
}

#pragma mark - concepts

- (void)getConceptsOnPage:(int)page pageSize:(int)pageSize completion:(ClarifaiSearchConceptCompletion)completion {
  [self ensureValidAccessToken:^(NSError *error) {
    if (error) {
      SafeRunBlock(completion, nil, error);
      return;
    }
    NSString *apiURL = [kApiBaseUrl stringByAppendingString:@"/concepts"];
    [_sessionManager GET:@"" parameters:nil success:^(NSURLSessionDataTask * _Nonnull task, id  _Nonnull responseObject) {
      
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
      
    }];
    [_sessionManager GET:apiURL
              parameters:@{ @"page": @(page), @"per_page": @(pageSize) }
                 success:^(NSURLSessionDataTask *task, id response) {
                   NSMutableArray *concepts = [NSMutableArray array];
                   NSArray *conceptsResponse = response[@"concepts"];
                   for (NSDictionary *concept in conceptsResponse) {
                     [concepts addObject:[[ClarifaiConcept alloc] initWithDictionary:concept]];
                   }
                   completion(concepts, nil);
                 } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
                   completion(nil, error);
                 }];
  }];
}

- (void)getConcept:(NSString *)conceptID completion:(ClarifaiStoreConceptCompletion)completion {
  [self ensureValidAccessToken:^(NSError *error) {
    if (error) {
      SafeRunBlock(completion, nil, error);
      return;
    }
    NSString *inputURLSuffix = [NSString stringWithFormat:@"/concepts/%@", conceptID];
    NSString *apiURL = [kApiBaseUrl stringByAppendingString:inputURLSuffix];
    
    [_sessionManager GET:apiURL
              parameters:nil
                progress:nil
                 success:^(NSURLSessionDataTask *task, id response) {
      ClarifaiConcept *concept = [[ClarifaiConcept alloc] initWithDictionary:response[@"concept"]];
      completion(concept, nil);
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
      completion(nil, error);
    }];
  }];
}

- (void)addConcepts:(NSArray <ClarifaiConcept *> *)concepts completion:(ClarifaiConceptsCompletion)completion {
  [self ensureValidAccessToken:^(NSError *error) {
    if (error) {
      SafeRunBlock(completion, nil, error);
      return;
    }
    NSMutableArray *conceptsArray = [NSMutableArray array];
    
    for (ClarifaiConcept *concept in concepts) {
      NSMutableDictionary *conceptDict = [NSMutableDictionary dictionary];
      conceptDict[@"id"] = concept.conceptID;
      if (concept.conceptName) {
        conceptDict[@"name"] = concept.conceptName;
      } else {
        conceptDict[@"name"] = concept.conceptID;
      }
      [conceptsArray addObject:conceptDict];
    }
    
    NSDictionary *params = @{ @"concepts": conceptsArray };
    
    
    NSString *apiURL = [kApiBaseUrl stringByAppendingString:@"/concepts/"];
    
    [_sessionManager POST:apiURL
               parameters:params
                 progress:nil
                  success:^(NSURLSessionDataTask *task, id response) {
                    NSMutableArray *conceptsArray = [NSMutableArray array];
                    NSArray *conceptsResponse = response[@"concepts"];
                    for (NSDictionary *concept in conceptsResponse) {
                      [conceptsArray addObject:[[ClarifaiConcept alloc] initWithDictionary:concept]];
                    }
                    completion(conceptsArray, nil);
                  } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
                    completion(nil, error);
                  }];
  }];
}

#pragma mark - Search

- (NSDictionary *)formatItemForSearch:(ClarifaiSearchTerm *)searchTerm {
  if ([searchTerm.searchItem isKindOfClass:[ClarifaiInput class]]) {
    ClarifaiImage *image = (ClarifaiImage *)searchTerm.searchItem;
    if (image.inputID) {
      if (searchTerm.isInput) {
        return @{@"input": @{@"id": image.inputID, @"data": @{@"image": @{@"crop": @[@(image.crop.top),
                                                                                     @(image.crop.left),
                                                                                     @(image.crop.bottom),
                                                                                     @(image.crop.right)]}}}};
      } else {
        return  @{@"output": @{@"input": @{@"id": image.inputID, @"data": @{@"image": @{@"crop": @[@(image.crop.top),
                                                                                                   @(image.crop.left),
                                                                                                   @(image.crop.bottom),
                                                                                                   @(image.crop.right)]}}}}};
      }
    } else if (image.mediaURL) {
      if (searchTerm.isInput) {
        return @{@"input": @{@"data": @{@"image": @{@"url": image.mediaURL }}}};
      } else {
        return @{@"output": @{@"input": @{@"data": @{@"image": @{@"url": image.mediaURL }}}}};
      }
    } else if (image.mediaData) {
      if (searchTerm.isInput) {
        return @{@"input": @{@"data": @{@"image": @{@"base64": [image.mediaData
                                                                base64EncodedStringWithOptions:NSDataBase64Encoding64CharacterLineLength] }}}};
      } else {
        return @{@"output": @{@"input": @{@"data": @{@"image": @{@"base64": [image.mediaData
                                                                             base64EncodedStringWithOptions:NSDataBase64Encoding64CharacterLineLength] }}}}};
      }
    } else if (image.metadata) {
      if (searchTerm.isInput) {
        return @{@"input": @{@"data": @{@"metadata": image.metadata}}};
      } else {
        return @{@"output": @{@"input": @{@"data": @{@"metadata": image.metadata}}}};
      }
    }
  } else if ([searchTerm.searchItem isKindOfClass:[ClarifaiConcept class]]) {
    ClarifaiConcept *concept = (ClarifaiConcept *)searchTerm.searchItem;
    if (concept.conceptName) {
      if (searchTerm.isInput) {
        return @{@"input": @{@"data": @{@"concepts": @[ @{@"name": concept.conceptName}]}}};
      } else {
        return @{@"output": @{@"data": @{@"concepts": @[ @{@"name": concept.conceptName}]}}};
      }
    } else if (concept.conceptID) {
      if (searchTerm.isInput) {
        return @{@"input": @{@"data": @{@"concepts": @[ @{@"id": concept.conceptID}]}}};
      } else {
        return @{@"output": @{@"data": @{@"concepts": @[ @{@"id": concept.conceptID}]}}};
      }
    }

  }
  return nil;
}

- (void)search:(NSArray <ClarifaiSearchTerm *> *)searchTerms
          page:(NSNumber *)page
       perPage:(NSNumber *)perPage
      language:(NSString *)language
    completion:(ClarifaiSearchCompletion)completion {
  [self ensureValidAccessToken:^(NSError *error) {
    if (error) {
      completion(nil, error);
    } else {
      NSString *apiURL = [kApiBaseUrl stringByAppendingString:@"/searches"];
      
      NSMutableArray *ands = [NSMutableArray array];
      
      for (ClarifaiSearchTerm *term in searchTerms) {
        NSDictionary *termBlock = [self formatItemForSearch:term];
        [ands addObject: termBlock];
      }
      
      NSMutableDictionary *query = [NSMutableDictionary dictionary];
      query[@"ands"] = ands;
      if (language != nil) {
        query[@"language"] = language;
      }
      NSDictionary *pagination = @{@"page": page, @"per_page": perPage};
        NSDictionary *params = @{@"query": query, @"pagination":pagination};
      
      [_sessionManager POST:apiURL
                 parameters:params
                   progress:nil
                    success:^(NSURLSessionDataTask *task, id response) {
        NSArray *hits = response[@"hits"];
        NSArray<ClarifaiSearchResult *> *searchResults = [hits map:^(NSDictionary *hit) {
          return [[ClarifaiSearchResult alloc] initWithDictionary:hit];
        }];
        completion(searchResults, nil);
      } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        completion(nil, error);
      }];
    }
  }];
}

- (void)searchByMetadata:(NSDictionary *)metadata
                    page:(NSNumber *)page
                 perPage:(NSNumber *)perPage
                 isInput:(BOOL)isInput
              completion:(ClarifaiSearchCompletion)completion {
  [self ensureValidAccessToken:^(NSError *error) {
    if (error) {
      completion(nil, error);
    } else {
      NSString *apiURL = [kApiBaseUrl stringByAppendingString:@"/searches"];
      
      NSMutableDictionary *query = [NSMutableDictionary dictionary];
      if (isInput) {
        query[@"ands"] = @[ @{@"input": @{@"data":@{@"metadata": metadata}}} ];
      } else {
        query[@"ands"] = @[ @{@"output": @{@"input": @{@"data":@{@"metadata": metadata}}}} ];
      }
      
      NSDictionary *pagination = @{@"page": page, @"per_page": perPage};
      
      [_sessionManager POST:apiURL
                 parameters:@{@"query": query, @"pagination":pagination}
                   progress:nil
                    success:^(NSURLSessionDataTask *task, id response) {
        NSArray *hits = response[@"hits"];
        NSArray<ClarifaiSearchResult *> *searchResults = [hits map:^(NSDictionary *hit) {
          return [[ClarifaiSearchResult alloc] initWithDictionary:hit];
        }];
        completion(searchResults, nil);
      } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        completion(nil, error);
      }];
    }
  }];
}

- (void)searchForConceptsByName:(NSString *)name andLanguage:(NSString *)language completion:(ClarifaiSearchConceptCompletion)completion {
  [self ensureValidAccessToken:^(NSError *error) {
    if (error) {
      completion(nil, error);
    } else {
      NSMutableDictionary *params = [NSMutableDictionary dictionary];
      params[@"concept_query"] = @{@"name":name, @"language": language ? language : @"zh"};
      
      NSString *apiURL = [kApiBaseUrl stringByAppendingString:@"/concepts/searches"];
      [_sessionManager POST:apiURL
                 parameters:params
                   progress:nil
                    success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable response) {
                      NSMutableArray *concepts = [NSMutableArray array];
                      for (NSDictionary *conceptDict in response[@"concepts"]) {
                        [concepts addObject:[[ClarifaiConcept alloc] initWithDictionary:conceptDict]];
                      }
                      completion(concepts, nil);
                    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
                      completion(nil, error);
                    }];
    }
  }];
}

#pragma mark - Model

- (void)getModels:(int)page resultsPerPage:(int)resultsPerPage completion:(ClarifaiModelsCompletion)completion {
  [self ensureValidAccessToken:^(NSError *error) {
    if (error) {
      SafeRunBlock(completion, nil, error);
      return;
    }
    NSString *apiURL = [kApiBaseUrl stringByAppendingString:@"/models"];
    
    [_sessionManager GET:apiURL
              parameters:@{@"page": @(page), @"per_page": @(resultsPerPage)}
                progress:nil
                 success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
      NSMutableArray *clarifaiModels = [NSMutableArray array];
      NSArray *models = responseObject[@"models"];
      for (NSDictionary *model in models) {
        ClarifaiModel *clarifaiModel = [[ClarifaiModel alloc] initWithDictionary:model];
        clarifaiModel.app = self;
        [clarifaiModels addObject:clarifaiModel];
      }
      completion(clarifaiModels, nil);
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
      completion(nil, error);
    }];
  }];
}

- (void)getModelByID:(NSString *)modelID completion:(ClarifaiModelCompletion)completion {
  [self ensureValidAccessToken:^(NSError *error) {
    if (error) {
      SafeRunBlock(completion, nil, error);
      return;
    }
    NSString *apiURL = [NSString stringWithFormat:@"%@/models/%@/output_info", kApiBaseUrl, modelID];
    
    [_sessionManager GET:apiURL
              parameters:nil
                progress:nil
                 success:^(NSURLSessionDataTask *task, id response) {
      ClarifaiModel *model;
      model = [[ClarifaiModel alloc] initWithDictionary:response[@"model"]];
      model.app = self;
      completion(model, nil);
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
      completion(nil, error);
    }];
  }];
}

- (void)getModelByName:(NSString *)modelName completion:(ClarifaiModelCompletion)completion {
  [self ensureValidAccessToken:^(NSError *error) {
    if (error) {
      SafeRunBlock(completion, nil, error);
      return;
    }
    [self searchForModelByName:modelName modelType:ClarifaiModelTypeConcept completion:^(NSArray<ClarifaiModel *> *models, NSError *error) {
      if (error) {
        SafeRunBlock(completion, nil, error);
      }
      if (models.count > 0) {
        SafeRunBlock(completion, models[0], nil);
      } else {
        SafeRunBlock(completion, nil, nil);
      }
    }];
  }];
}

- (void)mergeConcepts:(NSArray <ClarifaiConcept *> *)concepts forModelWithID:(NSString *)modelID completion:(ClarifaiModelCompletion)completion {
    [self ensureValidAccessToken:^(NSError *error) {
        if (error) {
            SafeRunBlock(completion, nil, error);
            return;
        }
        // Create concepts array.
        NSMutableArray *conceptsArray = [NSMutableArray array];
        for (ClarifaiConcept *concept in concepts) {
            NSMutableDictionary *conceptDict = [NSMutableDictionary dictionary];
            conceptDict[@"id"] = concept.conceptID;
            [conceptsArray addObject:conceptDict];
        }
        
        // Create model array of one model with given ID.
        NSDictionary *modelDict = @{@"id":modelID,
                                           @"output_info":@{@"data":@{@"concepts":conceptsArray}}};
        NSArray *modelArray = @[modelDict];
        
        // Add all to params.
        NSMutableDictionary *params = [NSMutableDictionary dictionary];
        params[@"models"] = modelArray;
        params[@"action"] = @"merge";
        
        NSString *apiURL = [kApiBaseUrl stringByAppendingString:@"/models/"];
      
        [_sessionManager PATCH:apiURL
                    parameters:params
                       success:^(NSURLSessionDataTask *task, id response) {
                         NSDictionary *status = response[@"status"];
                         long code = [status[@"code"] longValue];
                         if (code == 10000) {
                           ClarifaiModel *model = [[ClarifaiModel alloc] initWithDictionary:response[@"models"][0]];
                           completion(model, nil);
                         } else if (code == 21202) {
                           NSError *error = [[NSError alloc] initWithDomain:kErrorDomain
                                                                       code:400
                                                                   userInfo:@{@"description": status[@"description"],
                                                                              @"details": status[@"details"]}];
                           completion(nil, error);
                         }
                       } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
                         completion(nil, error);
                       }];
    }];
}

- (void)setConcepts:(NSArray <ClarifaiConcept *> *)concepts forModelWithID:(NSString *)modelID completion:(ClarifaiModelCompletion)completion {
    [self ensureValidAccessToken:^(NSError *error) {
        if (error) {
            SafeRunBlock(completion, nil, error);
            return;
        }
        // Create concepts array.
        NSMutableArray *conceptsArray = [NSMutableArray array];
        for (ClarifaiConcept *concept in concepts) {
            NSMutableDictionary *conceptDict = [NSMutableDictionary dictionary];
            conceptDict[@"id"] = concept.conceptID;
            [conceptsArray addObject:conceptDict];
        }
        
        // Create model array of one model with given ID.
        NSDictionary *modelDict = @{@"id":modelID,
                                           @"output_info":@{@"data":@{@"concepts":conceptsArray}}};
        NSArray *modelArray = @[modelDict];
        
        // Add all to params.
        NSMutableDictionary *params = [NSMutableDictionary dictionary];
        params[@"models"] = modelArray;
        params[@"action"] = @"overwrite";
        
      NSString *apiURL = [kApiBaseUrl stringByAppendingString:@"/models/"];
      
      [_sessionManager PATCH:apiURL
                  parameters:params
                     success:^(NSURLSessionDataTask *task, id response) {
                       NSDictionary *status = response[@"status"];
                       long code = [status[@"code"] longValue];
                       if (code == 10000) {
                         ClarifaiModel *model = [[ClarifaiModel alloc] initWithDictionary:response[@"models"][0]];
                         completion(model, nil);
                       } else if (code == 21202) {
                         NSError *error = [[NSError alloc] initWithDomain:kErrorDomain
                                                                     code:400
                                                                 userInfo:@{@"description": status[@"description"],
                                                                            @"details": status[@"details"]}];
                         completion(nil, error);
                       }
                     } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
                       completion(nil, error);
                     }];
    }];
}

- (void)deleteConcepts:(NSArray <ClarifaiConcept *> *)concepts fromModelWithID:(NSString *)modelID completion:(ClarifaiModelCompletion)completion {
    [self ensureValidAccessToken:^(NSError *error) {
        if (error) {
            SafeRunBlock(completion, nil, error);
            return;
        }
        // Create concepts array.
        NSMutableArray *conceptsArray = [NSMutableArray array];
        for (ClarifaiConcept *concept in concepts) {
            NSMutableDictionary *conceptDict = [NSMutableDictionary dictionary];
            conceptDict[@"id"] = concept.conceptID;
            [conceptsArray addObject:conceptDict];
        }
        
        // Create model array of one model with given ID.
        NSDictionary *modelDict = @{@"id":modelID,
                                           @"output_info":@{@"data":@{@"concepts":conceptsArray}}};
        NSArray *modelArray = @[modelDict];
        
        // Add all to params.
        NSMutableDictionary *params = [NSMutableDictionary dictionary];
        params[@"models"] = modelArray;
        params[@"action"] = @"remove";
        
        NSString *apiURL = [kApiBaseUrl stringByAppendingString:@"/models/"];

        [_sessionManager PATCH:apiURL
                    parameters:params
                       success:^(NSURLSessionDataTask *task, id response) {
                         NSDictionary *status = response[@"status"];
                         long code = [status[@"code"] longValue];
                         if (code == 10000) {
                           ClarifaiModel *model = [[ClarifaiModel alloc] initWithDictionary:response[@"models"][0]];
                           completion(model, nil);
                         } else if (code == 21202) {
                           NSError *error = [[NSError alloc] initWithDomain:kErrorDomain
                                                                       code:400
                                                                   userInfo:@{@"description": status[@"description"],
                                                                              @"details": status[@"details"]}];
                           completion(nil, error);
                         }
                         
                       } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
                         completion(nil, error);
                       }];
    }];
}

- (void)listVersionsForModel:(NSString *)modelID
                        page:(int)page
              resultsPerPage:(int)resultsPerPage
                  completion:(ClarifaiModelVersionsCompletion)completion {
  [self ensureValidAccessToken:^(NSError *error) {
    if (error) {
      SafeRunBlock(completion, nil, error);
      return;
    }
    NSString *apiURL = [NSString stringWithFormat:@"%@/models/%@/versions?page=%i&per_page=%i", kApiBaseUrl, modelID, page, resultsPerPage];
    
    [_sessionManager GET:apiURL
              parameters:nil
                progress:nil
                 success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
      NSMutableArray *versions = [NSMutableArray array];
      NSArray *versionDicts = responseObject[@"model_versions"];
      for (NSDictionary *versionDict in versionDicts) {
        ClarifaiModelVersion *version = [[ClarifaiModelVersion alloc] initWithDictionary:versionDict];
        [versions addObject:version];
      }
      completion(versions, nil);
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
      completion(nil, error);
    }];
  }];
}

- (void)getVersionForModel:(NSString *)modelID
                 versionID:(NSString *)versionID
                completion:(ClarifaiModelVersionCompletion)completion {
  [self ensureValidAccessToken:^(NSError *error) {
    if (error) {
      SafeRunBlock(completion, nil, error);
      return;
    }
    NSString *apiURL = [NSString stringWithFormat:@"%@/models/%@/versions/%@/", kApiBaseUrl, modelID, versionID];
    
    [_sessionManager GET:apiURL
              parameters:nil
                progress:nil
                 success:^(NSURLSessionDataTask *task, id response) {
      ClarifaiModelVersion *version = [[ClarifaiModelVersion alloc] initWithDictionary:response[@"model_version"]];
      completion(version, nil);
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
      completion(nil, error);
    }];
  }];
}

- (void)deleteVersionForModel:(NSString *)modelID
                    versionID:(NSString *)versionID
                   completion:(ClarifaiRequestCompletion)completion {
  [self ensureValidAccessToken:^(NSError *error) {
    if (error) {
      SafeRunBlock(completion, error);
      return;
    }
    NSString *apiURL = [NSString stringWithFormat:@"%@/models/%@/versions/%@/", kApiBaseUrl, modelID, versionID];
    
    [_sessionManager DELETE:apiURL
                 parameters:nil
                    success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
      completion(nil);
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
      completion(error);
    }];
  }];
}

- (void)listTrainingInputsForModel:(NSString *)modelID
                        page:(int)page
              resultsPerPage:(int)resultsPerPage
                  completion:(ClarifaiInputsCompletion)completion {
  [self ensureValidAccessToken:^(NSError *error) {
    if (error) {
      SafeRunBlock(completion, nil, error);
      return;
    }
    NSString *apiURL = [NSString stringWithFormat:@"%@/models/%@/inputs?page=%i&per_page=%i", kApiBaseUrl, modelID, page, resultsPerPage];
    
    [_sessionManager GET:apiURL
              parameters:nil
                progress:nil
                 success:^(NSURLSessionDataTask *task, id responseObject) {
      NSMutableArray *inputs = [NSMutableArray array];
      NSArray *inputDicts = responseObject[@"inputs"];
      for (NSDictionary *inputDict in inputDicts) {
        ClarifaiInput *input = [[ClarifaiInput alloc] initWithDictionary:inputDict];
        [inputs addObject:input];
      }
      completion(inputs, nil);
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
      completion(nil, error);
    }];
  }];
}

- (void)listTrainingInputsForModel:(NSString *)modelID
                           version:(NSString *)versionID
                              page:(int)page
                    resultsPerPage:(int)resultsPerPage
                        completion:(ClarifaiInputsCompletion)completion {
  [self ensureValidAccessToken:^(NSError *error) {
    if (error) {
      SafeRunBlock(completion, nil, error);
      return;
    }
    NSString *apiURL = [NSString stringWithFormat:@"%@/models/%@/versions/%@/inputs?page=%i&per_page=%i", kApiBaseUrl, modelID, versionID, page, resultsPerPage];
    
    [_sessionManager GET:apiURL
              parameters:nil
                progress:nil
                 success:^(NSURLSessionDataTask *task, id response) {
      NSMutableArray *inputs = [NSMutableArray array];
      NSArray *inputDicts = response[@"inputs"];
      for (NSDictionary *inputDict in inputDicts) {
        ClarifaiInput *input = [[ClarifaiInput alloc] initWithDictionary:inputDict];
        [inputs addObject:input];
      }
      completion(inputs, nil);
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
      completion(nil, error);
    }];
  }];
}

- (void)searchForModelByName:(NSString *)modelName
                   modelType:(ClarifaiModelType)modelType
                  completion:(ClarifaiModelsCompletion)completion {
  [self ensureValidAccessToken:^(NSError *error) {
    if (error) {
      SafeRunBlock(completion, nil, error);
      return;
    }
    NSString *apiURL = [kApiBaseUrl stringByAppendingString:@"/models/searches"];
    NSDictionary *params = @{@"model_query": @{@"name": modelName, @"type": _modelTypes[@(modelType)]}};
    
    [_sessionManager POST:apiURL
               parameters:params
                 progress:nil
                  success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
      NSMutableArray *clarifaiModels = [NSMutableArray array];
      NSArray *models = responseObject[@"models"];
      for (NSDictionary *model in models) {
        ClarifaiModel *clarifaiModel = [[ClarifaiModel alloc] initWithDictionary:model];
        clarifaiModel.app = self;
        [clarifaiModels addObject:clarifaiModel];
      }
      completion(clarifaiModels, nil);
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
      completion(nil, error);
    }];
  }];
}

- (void)createModel:(NSArray *)concepts
               name:(NSString *)modelName
  conceptsMutuallyExclusive:(BOOL)conceptsMutuallyExclusive
  closedEnvironment:(BOOL)closedEnvironment
         completion:(ClarifaiModelCompletion)completion {
  
  // Call createModel below using the modelName as both the name and ID.
  [self createModel:concepts name:modelName modelID:modelName conceptsMutuallyExclusive:conceptsMutuallyExclusive closedEnvironment:closedEnvironment completion:completion];
 }

- (void)createModel:(NSArray *)concepts
               name:(NSString *)modelName
                 modelID:(NSString *)modelID
conceptsMutuallyExclusive:(BOOL)conceptsMutuallyExclusive
  closedEnvironment:(BOOL)closedEnvironment
         completion:(ClarifaiModelCompletion)completion {
  [self ensureValidAccessToken:^(NSError *error) {
    if (error) {
      SafeRunBlock(completion, nil, error);
      return;
    }
    
    NSArray *conceptsArray = [concepts map:^(id concept) {
      if ([concept isKindOfClass:[NSString class]]) {
        return @{@"id": (NSString *)concept};
      } else {
        ClarifaiConcept *actualConcept = (ClarifaiConcept *)concept;
        return @{@"id": actualConcept.conceptID};
      }
    }];
    
    NSDictionary *model =
    @{
      @"model": @{
          @"name": modelName,
          @"id": modelID,
          @"output_info": @{
              @"data": @{
                  @"concepts": conceptsArray
                  },
              @"output_config": @{
                  @"concepts_mutually_exclusive": conceptsMutuallyExclusive ? @YES : @NO,
                  @"closed_environment": closedEnvironment ? @YES : @NO
                  }
              }
          }
      };
    
    NSString *apiURL = [kApiBaseUrl stringByAppendingString:@"/models"];
    
    [_sessionManager POST:apiURL
               parameters:model
                 progress:nil
                  success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
      NSDictionary *status = responseObject[@"status"];
      long code = [status[@"code"] longValue];
      if (code == 10000) {
        ClarifaiModel *model = [[ClarifaiModel alloc] initWithDictionary:responseObject[@"model"]];
        model.app = self;
        completion(model, nil);
      } else if (code == 21202) {
        NSError *error = [[NSError alloc] initWithDomain:kErrorDomain
                                                    code:400
                                                userInfo:@{@"description": status[@"description"],
                                                           @"details": status[@"details"]}];
        completion(nil, error);
      }
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
      completion(nil, error);
    }];
  }];
}

- (void)deleteModel:(NSString *)modelID completion:(ClarifaiRequestCompletion)completion {
  [self ensureValidAccessToken:^(NSError *error) {
    if (error) {
      SafeRunBlock(completion, error);
      return;
    }
    NSString *endpoint = [NSString stringWithFormat:@"/models/%@", modelID];
    NSString *apiURL = [kApiBaseUrl stringByAppendingString:endpoint];
    
    [_sessionManager DELETE:apiURL
                 parameters:nil
                    success:^(NSURLSessionDataTask *task, id response) {
      completion(nil);
    } failure:^(NSURLSessionDataTask *task, NSError *error) {
      completion(error);
    }];
  }];
}

- (void)deleteAllModels:(ClarifaiRequestCompletion)completion {
  [self ensureValidAccessToken:^(NSError *error) {
    if (error) {
      SafeRunBlock(completion, error);
      return;
    }
    NSString *endpoint = @"/models/";
    NSString *apiURL = [kApiBaseUrl stringByAppendingString:endpoint];
    
    [_sessionManager DELETE:apiURL
                 parameters:@{@"delete_all":@YES}
                    success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
      completion(nil);
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
      completion(error);
    }];
  }];
}

- (void)deleteModelsByIDList:(NSArray *)models completion:(ClarifaiRequestCompletion)completion {
    [self ensureValidAccessToken:^(NSError *error) {
        if (error) {
            SafeRunBlock(completion, error);
            return;
        }
        
        NSMutableArray *modelsArray = [NSMutableArray array];
        for (id model in models) {
            if ([model isKindOfClass:[NSString class]]) {
                 [modelsArray addObject:model];
            } else if ([model isKindOfClass:[ClarifaiModel class]]) {
                [modelsArray addObject:((ClarifaiModel *)model).modelID];
            }
        }
        
        NSMutableDictionary *params = [NSMutableDictionary dictionary];
        params[@"ids"] = modelsArray;
        
        NSString *inputURLSuffix = @"/models/";
        NSString *apiURL = [kApiBaseUrl stringByAppendingString:inputURLSuffix];
      
        [_sessionManager DELETE:apiURL
                     parameters:params
                        success:^(NSURLSessionDataTask *task, id response) {
          completion(nil);
        } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
          completion(error);
        }];
    }];
}

- (void)getOutputInfoForModel:(NSString *)modelID completion:(ClarifaiModelCompletion)completion {
  [self ensureValidAccessToken:^(NSError *error) {
    if (error) {
      SafeRunBlock(completion, nil, error);
      return;
    }
    NSString *apiURL = [NSString stringWithFormat:@"%@/models/%@/output_info", kApiBaseUrl, modelID];
    
    [_sessionManager GET:apiURL
              parameters:nil
                progress:nil
                 success:^(NSURLSessionDataTask *task, id response) {
      ClarifaiModel *model = [[ClarifaiModel alloc] initWithDictionary:response[@"model"]];
      completion(model, nil);
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
      completion(nil, error);
    }];
  }];
}

- (void)updateModel:(NSString *)modelID
               name:(NSString *)modelName
conceptsMutuallyExclusive:(BOOL)conceptsMutuallyExclusive
  closedEnvironment:(BOOL)closedEnvironment
         completion:(ClarifaiModelCompletion)completion {
    [self ensureValidAccessToken:^(NSError *error) {
        if (error) {
            SafeRunBlock(completion, nil, error);
            return;
        }
        
        // Create model array of one model with given ID.
        NSDictionary *modelDict = @{@"id":modelID,
                                    @"name":modelName,
                                    @"output_info":@{
                                            @"output_config":@{
                                                    @"concepts_mutually_exclusive":conceptsMutuallyExclusive? @YES : @NO,
                                                    @"closed_environment":closedEnvironment ? @YES : @NO
                                                    }
                                            }
                                    };
        
        NSArray *modelArray = @[modelDict];
        
        // Add all to params.
        NSMutableDictionary *params = [NSMutableDictionary dictionary];
        params[@"models"] = modelArray;
        
        NSString *apiURL = [kApiBaseUrl stringByAppendingString:@"/models/"];
        [_sessionManager PATCH:apiURL
                 parameters:params
                    success:^(NSURLSessionDataTask *task, id response) {
                        NSDictionary *status = response[@"status"];
                        long code = [status[@"code"] longValue];
                        if (code == 10000) {
                            ClarifaiModel *model = [[ClarifaiModel alloc] initWithDictionary:response[@"model"]];
                            completion(model, nil);
                        } else if (code == 21202) {
                            NSError *error = [[NSError alloc] initWithDomain:kErrorDomain
                                                                        code:400
                                                                    userInfo:@{@"description": status[@"description"],
                                                                               @"details": status[@"details"]}];
                            completion(nil, error);
                        }
                    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
                        completion(nil, error);
                    }];
        
    }];
}


#pragma mark - Access Token Management

- (void)setAccessToken:(NSString *)accessToken {
  _accessToken = accessToken;
  NSString *value = [NSString stringWithFormat:@"Bearer %@", self.accessToken];
  [_sessionManager.requestSerializer setValue:value forHTTPHeaderField:@"Authorization"];
  [_sessionManager.requestSerializer setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
  [_sessionManager.requestSerializer setValue:@"objc:2.2.0" forHTTPHeaderField:@"X-Clarifai-Client"];
}

- (void)ensureValidAccessToken:(void (^)(NSError *error))handler {
  if (self.accessToken && self.accessTokenExpiration &&
      [self.accessTokenExpiration timeIntervalSinceNow] >= kMinTokenLifetime) {
    handler(nil);  // We have a valid access token.
  } else {
    self.authenticating = YES;
    // Send a request to the auth endpoint. See: https://developer.clarifai.com/docs/auth.
    NSString *clientSecret = [NSString stringWithFormat:@"%@:%@", self.appID, self.appSecret];
    NSData *clientSecretData = [clientSecret dataUsingEncoding:NSUTF8StringEncoding];
    NSString *clientSecretBase64 = [clientSecretData base64EncodedStringWithOptions:NSDataBase64EncodingEndLineWithLineFeed];
    [_sessionManager.requestSerializer setValue:[@"Basic " stringByAppendingString:clientSecretBase64] forHTTPHeaderField:@"Authorization"];
    
    [_sessionManager POST:[kApiBaseUrl stringByAppendingString:@"/token"] parameters:nil progress:nil success:^(NSURLSessionDataTask *task, id response) {
      ClarifaiAccessTokenResponse *res = [[ClarifaiAccessTokenResponse alloc]
                                          initWithDictionary:response];
      [self saveAccessToken:res];
      self.authenticating = NO;
      handler(nil);
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
      self.authenticating = NO;
      handler(error);
    }];
  }
}

- (void)loadAccessToken {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  if (![self.appID isEqualToString:[defaults valueForKey:kKeyAppID]]) {
    [self invalidateAccessToken];
  } else {
    self.accessToken = [defaults valueForKey:kKeyAccessToken];
    self.accessTokenExpiration = [defaults valueForKey:kKeyAccessTokenExpiration];
  }
}

- (void)saveAccessToken:(ClarifaiAccessTokenResponse *)response {
  if (response.accessToken) {
    NSDate *expiration = [NSDate dateWithTimeIntervalSinceNow:response.expiresIn];
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:response.accessToken forKey:kKeyAccessToken];
    [defaults setObject:expiration forKey:kKeyAccessTokenExpiration];
    [defaults setObject:self.appID forKey:kKeyAppID];
    [defaults synchronize];
    self.accessToken = response.accessToken;
    self.accessTokenExpiration = expiration;
  }
}

- (void)invalidateAccessToken {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  [defaults removeObjectForKey:kKeyAccessToken];
  [defaults removeObjectForKey:kKeyAccessTokenExpiration];
  [defaults removeObjectForKey:kKeyAppID];
  [defaults synchronize];
  self.accessToken = nil;
  self.accessTokenExpiration = nil;
}

#pragma mark -

/*
- (NSError *)errorFromHttpResponse:(NSHTTPURLResponse *)response {
  NSString *desc;
  if (op.responseString) {
    desc = response.respo
  }
}

- (NSError *)errorFromHttpResponse:(AFHTTPRequestOperation *)op {
  NSString *desc;
  if (op.responseString) {
    desc = op.responseString;
  } else {
    desc = [NSString stringWithFormat:@"HTTP Status %d", (int)op.response.statusCode];
  }
  NSString *url = [op.request.URL absoluteString];
  return [[NSError alloc] initWithDomain:kErrorDomain
                                    code:op.response.statusCode
                                userInfo:@{@"description": desc, @"url": url}];
}
*/


@end
