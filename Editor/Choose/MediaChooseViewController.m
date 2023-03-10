//
//  MediaChooseViewController.m
//  RanMediaTimeline
//
//  Created by zouran on 2021/12/30.
//

#import "MediaChooseViewController.h"
#import "MediaChooseCell.h"
#import <Photos/Photos.h>
#import "MediaChooseListView.h"
#import "UICollectionView+Extensions.h"
#import "EditorData.h"
#import "MediaInfo.h"
#import "FFMpegTool.h"
#import "EditorMaterial.h"
#import "ViewController.h"
#import "EditorVideoEffect.h"

@interface MediaChooseViewController ()<UICollectionViewDataSource,UICollectionViewDelegate,UICollectionViewDelegateFlowLayout>

@property (nonatomic, strong) UICollectionView *collectionView;
@property (nonatomic, strong) PHCachingImageManager *cachingImageManager;
@property (nonatomic, assign) CGRect previousPreheatRect;
@property (nonatomic, assign) CGSize thumbnailSize;
@property (nonatomic, strong) PHFetchResult<PHAsset *> *fetchResult;
@property (nonatomic, strong) MediaChooseListView *chooseListView;
@property (nonatomic, strong) NSMutableArray *selectedAssets;
@property (nonatomic, strong) UIButton *bottomButton;

@end

static NSString *CollectionCellIdentifier = @"cell";

@implementation MediaChooseViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    self.view.backgroundColor = [UIColor blackColor];
    self.selectedAssets = [NSMutableArray arrayWithCapacity:0];
    
    UIEdgeInsets bottomEdge;
    bottomEdge = UIEdgeInsetsZero;
    
    if (@available(iOS 11.0, *)) {
        bottomEdge =  [[[UIApplication sharedApplication] windows] objectAtIndex:0].safeAreaInsets;
    }
    
    UIView *bottomView = [UIView new];
    bottomView.backgroundColor = [UIColor blackColor];
    [self.view addSubview:bottomView];
    [bottomView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.bottom.equalTo(self.view);
        make.left.right.equalTo(self.view);
        if (@available(iOS 11.0, *)) {
            make.height.mas_equalTo(64 + bottomEdge.bottom);
        } else {
            make.height.mas_equalTo(64);
        }
    }];
    
    self.bottomButton = [UIButton new];
    [self.bottomButton setTitle:@"??????" forState:UIControlStateNormal];
    [self.bottomButton addTarget:self action:@selector(bottomButtonClick) forControlEvents:UIControlEventTouchUpInside];
    [self.bottomButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.bottomButton.enabled = NO;
    self.bottomButton.backgroundColor = [UIColor colorWithRed:254/255.0 green:44/255.0 blue:85/255.0 alpha:1];
    self.bottomButton.layer.cornerRadius = 2;
    self.bottomButton.layer.masksToBounds = YES;
    [bottomView addSubview:self.bottomButton];
    
   
    
    [self.bottomButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.right.equalTo(bottomView).inset(20);
        make.width.mas_equalTo(70);
        make.height.mas_equalTo(30);
        if (@available(iOS 11.0, *)) {
            make.bottom.equalTo(bottomView).inset(bottomEdge.bottom);
        } else {
            make.bottom.equalTo(bottomView).inset(10);
        }
    }];
    
    
    self.chooseListView = [[MediaChooseListView alloc] initWithFrame:CGRectZero];
    [self.view addSubview:self.chooseListView];
    [self.chooseListView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.bottom.equalTo(bottomView.mas_top);
        make.left.right.equalTo(self.view);
        if (@available(iOS 11.0, *)) {
            make.height.mas_equalTo((self.view.frame.size.width - 4 * 10) / 4.0 + bottomEdge.bottom);
        } else {
            make.height.mas_equalTo((self.view.frame.size.width - 4 * 10) / 4.0);
        }
    }];
    
    __weak typeof(self)weakSelf = self;
    self.chooseListView.didRefreshDataSource = ^(NSInteger index) {
        [weakSelf.collectionView reloadData];
    };

    UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
    self.collectionView = [[UICollectionView alloc] initWithFrame:CGRectZero collectionViewLayout:layout];
    [self.collectionView registerClass:[MediaChooseCell class] forCellWithReuseIdentifier:CollectionCellIdentifier];
    self.collectionView.backgroundColor = [UIColor blackColor];
    self.collectionView.contentInset = UIEdgeInsetsMake(0, 0, 80, 0);
    self.collectionView.showsVerticalScrollIndicator = FALSE;
    self.collectionView.showsHorizontalScrollIndicator = FALSE;
//    self.collectionView.backgroundColor = [UIColor blueColor];
    self.collectionView.delegate = self;
    self.collectionView.dataSource = self;
    [self.view addSubview:self.collectionView];
    [self.collectionView mas_makeConstraints:^(MASConstraintMaker *make) {
        if (@available(iOS 11.0, *)) {
            make.top.mas_equalTo(44 + bottomEdge.top);
        } else {
            make.top.mas_equalTo(44);
        }
        make.left.right.equalTo(self.view);
        make.bottom.equalTo(self.chooseListView.mas_top);
    }];
    
    [self resetCachedAssets];
    
    CGFloat scale = UIScreen.mainScreen.scale;
    CGSize cellSize = ((UICollectionViewFlowLayout *)layout).itemSize;
    self.thumbnailSize = CGSizeMake(cellSize.width * scale, cellSize.height * scale);
    
    [self updateCachedAssets];
    [self checkPhotoLibraryPrivacy];
    [self loadAssets];
}

- (void)checkPhotoLibraryPrivacy {
    
    PHAuthorizationStatus status = [PHPhotoLibrary authorizationStatus];
    switch (status) {
        case PHAuthorizationStatusRestricted:
        case PHAuthorizationStatusDenied:
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                UIAlertController *alert = [UIAlertController alertControllerWithTitle:nil message:@"??????iPhone????????????-??????-????????????????????????????????????????????????" preferredStyle:UIAlertControllerStyleAlert];
                UIAlertAction *submitAction = [UIAlertAction actionWithTitle:@"??????" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                    NSURL *url = [NSURL URLWithString:UIApplicationOpenSettingsURLString];
                    [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:NULL];
                }];
                UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"??????" style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
                }];
                [alert addAction:submitAction];
                [alert addAction:cancelAction];
                [self presentViewController:alert animated:YES completion:nil];
            });
            
            break;
        }
        case PHAuthorizationStatusAuthorized: {
            {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self loadAssets];
                });
            }
            break;
        }
        case PHAuthorizationStatusNotDetermined:
        {
            [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus status) {
                if (@available(iOS 14, *)) {
                    if (status == PHAuthorizationStatusAuthorized || status == PHAuthorizationStatusLimited) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [self loadAssets];
                        });
                    }
                } else {
                    if (status == PHAuthorizationStatusAuthorized) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [self loadAssets];
                        });
                    }
                }
            }];
            break;
        }
        case PHAuthorizationStatusLimited:
            if (@available(iOS 14, *)) {
                
            }
            break;
    }
    
}

- (void)bottomButtonClick {
    if (self.selectedAssets.count != 2) {
        MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
        hud.mode = MBProgressHUDModeText;
        hud.label.text = @"?????????????????????";
        [hud hideAnimated:YES afterDelay:3];
        return;
    }
    [self ffmpegSaveLocalPath:@""];
}

// ??????????????????
- (void)ffmpegSaveLocalPath:(NSString *)fromPath {
    __block EditorData *editorData = [EditorData sharedInstance];
    __block EditorMaterial *materials = [[EditorMaterial alloc] init];
    editorData.materials = materials;
    
    dispatch_group_t group = dispatch_group_create();
    
    // ??????
    MediaTrack *mainTrack = [[MediaTrack alloc] init];
    mainTrack.type = MediaTrackTypeVideo;
    [editorData.tracks addObject:mainTrack];
    
    // ?????????
    MediaTrack *effectsTrack = [[MediaTrack alloc] init];
    effectsTrack.type = MediaTrackTypeEffect;
    [editorData.tracks addObject:effectsTrack];
    
    MediaSegment *effectSegment1 = [[MediaSegment alloc] init];
    effectSegment1.target_timerange = [[MediaTimeRange alloc] initWithTimeRangeStart:0 timeRangeDuration:3000000];
    
    EditorVideoEffect *videoEffect = [[EditorVideoEffect alloc] init];
    videoEffect.relation_id = [NSString media_GUIDString];
    videoEffect.path = [[NSBundle mainBundle] pathForResource:@"monochrome" ofType:@"fsh"];
    effectSegment1.material_id = videoEffect.relation_id;
    [materials.video_effects addObject:videoEffect];
    
    
    MediaSegment *effectSegment2 = [[MediaSegment alloc] init];
    effectSegment2.target_timerange = [[MediaTimeRange alloc] initWithTimeRangeStart:4000000 timeRangeDuration:3000000];
    
    EditorVideoEffect *videoEffect2 = [[EditorVideoEffect alloc] init];
    videoEffect2.relation_id = [NSString media_GUIDString];
    videoEffect2.path = [[NSBundle mainBundle] pathForResource:@"monochrome" ofType:@"fsh"];
    effectSegment2.material_id = videoEffect2.relation_id;
    [materials.video_effects addObject:videoEffect2];
    
    [effectsTrack.segments addObject:effectSegment1];
    [effectsTrack.segments addObject:effectSegment2];
    
    MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    hud.mode = MBProgressHUDModeDeterminate;
    hud.label.text = @"????????????????????????";
    
    __block uint64_t start = 0;
    for (int i = 0; i < self.selectedAssets.count; i ++) {
        PHAsset *a = self.selectedAssets[i];
        PHVideoRequestOptions *options = [[PHVideoRequestOptions alloc] init];
        options.version = PHVideoRequestOptionsVersionCurrent;
        options.deliveryMode = PHVideoRequestOptionsDeliveryModeHighQualityFormat;
        options.networkAccessAllowed = YES;
        dispatch_group_enter(group);
        [[PHImageManager defaultManager] requestAVAssetForVideo:a options:options resultHandler:^(AVAsset * _Nullable asset, AVAudioMix * _Nullable audioMix, NSDictionary * _Nullable info) {
            AVURLAsset *ass = (AVURLAsset *)asset;
            NSString *lowName = [[ass.URL.absoluteString pathExtension] lowercaseString];
            NSString *extension;
            if ([lowName isEqualToString:@"mov"]) {
                extension = @"mov";
            } else if ([lowName isEqualToString:@"mp4"]) {
                extension = @"mp4";
            } else {
                extension = @"mp4";
            }
            
            CFUUIDRef theUUID = CFUUIDCreate(NULL);
            CFStringRef string = CFUUIDCreateString(NULL, theUUID);
            CFRelease(theUUID);
            NSString *u = (__bridge_transfer NSString *)string ;
            NSDate* date = [NSDate dateWithTimeIntervalSinceNow:0];//??????????????????0???????????????
            NSTimeInterval time=[date timeIntervalSince1970]*1000;// *1000 ?????????????????????????????????????????????
            NSString *timeString = [NSString stringWithFormat:@"%.0f", time];
            u = [self findVideoPath:[NSString stringWithFormat:@"iOSALBUM@%@@%@.%@",u,timeString,extension]];
            
            NSLog(@"%@",u);
            
            if ([FFMpegTool exportAblumPhoto:[ass.URL.absoluteString UTF8String] toPath:[u UTF8String]] == 0) {
                MediaInfo *info = [FFMpegTool openStreamFunc:u];
                NSString *videoPath = u;
                EditorVideo *video = [[EditorVideo alloc] init];
                video.path = videoPath;
                video.width = info.width;
                video.height = info.height;
//                video.width = 1080;
//                video.height = 1620;
                video.media_id = [NSString media_GUIDString];
                
                EditorTransition *transition = [[EditorTransition alloc] init];
                transition.type = @"transition";
                transition.duration = 2000000;
                transition.path = [[NSBundle mainBundle] pathForResource:@"Heart" ofType:@"fsh"];
                
                MediaSegment *segment = [[MediaSegment alloc] init];
                MediaClip *clip = [[MediaClip alloc] init];
                segment.clip = clip;
                segment.source_timerange = [[MediaTimeRange alloc] initWithTimeRangeStart:0 timeRangeDuration:info.duration];
                segment.target_timerange = [[MediaTimeRange alloc] initWithTimeRangeStart:start timeRangeDuration:segment.source_timerange.duration];
                if (i == 0) {
                    CanvasConfig *config = [[CanvasConfig alloc] init];
                    config.width = video.width;
                    config.height = video.height;
                    config.ratio = CanvasRatioOriginal;
                    editorData.canvas_config = config;
                }
                
                clip.scale = [self setNormalTransformWithVideoSize:CGSizeMake(video.width, video.height)];
                segment.material_id = video.media_id;
                if (i < materials.transitions.count && materials.transitions.count > 0) {
                    transition = materials.transitions[i];
                }
                if (transition) {
                    start += (info.duration - transition.duration);
                } else {
                    start += info.duration;
                }
                
                [materials.transitions addObject:transition];
                [materials.videos addObject:video];
                [mainTrack.segments addObject:segment];
            }
             
            dispatch_group_leave(group);
        }];
    }
    
    dispatch_group_notify(group, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        dispatch_async(dispatch_get_main_queue(), ^{
            
//            NSString *modelStr = [editorData yy_modelToJSONString];
//            NSLog(@"final json %@",modelStr);
            
//            return;
            [hud hideAnimated:YES];
            ViewController *vc = [[ViewController alloc] init];
            vc.modalPresentationStyle = UIModalPresentationFullScreen;
            [self presentViewController:vc animated:YES completion:nil];
        });
    });
}

- (double)sizeFitCanvansSize:(CGSize)canvansSize sourceSize:(CGSize)sourceSize {
    // ??????????????????
    /*
     720p  1080p
     */
    double transfrom = 0.0;
    
    uint64_t canvansWidth = canvansSize.width;
    uint64_t canvansHeight = canvansSize.height;
    double canvansRadius = canvansWidth / (canvansHeight * 1.0);
    
    uint64_t sourceWidth = sourceSize.width;
    uint64_t sourceHeight = sourceSize.height;
    double sourceRadius = sourceWidth / (sourceHeight * 1.0);
    
    if (canvansRadius > sourceRadius) {
        // ????????? ?????????
        uint64_t newHeight = canvansHeight;
        uint64_t newWidth = sourceRadius * newHeight;
        transfrom = newWidth / (canvansWidth * 1.0);
        
        return transfrom;
    } else {
        uint64_t newWidth = canvansWidth;
        uint64_t newHeight = newWidth / sourceRadius;
        transfrom = newHeight / (canvansHeight * 1.0);
        return transfrom;
    }
    return 1.0;
}

- (MediaFloat *)setNormalTransformWithVideoSize:(CGSize)videoSize {
    MediaFloat *scale = [[MediaFloat alloc] init];
    CanvasConfig *config = [EditorData sharedInstance].canvas_config;

    CGSize canvansSize = CGSizeMake(config.width, config.height);

    double cgaffineTransform = [self sizeFitCanvansSize:canvansSize sourceSize:CGSizeMake(videoSize.width, videoSize.height)];

    uint64_t canvansWidth = canvansSize.width;
    uint64_t canvansHeight = canvansSize.height;
    double canvansRadius = canvansWidth / (canvansHeight * 1.0);

    CGSize sourceSize = CGSizeMake(videoSize.width, videoSize.height);
    uint64_t sourceWidth = sourceSize.width;
    uint64_t sourceHeight = sourceSize.height;
    double sourceRadius = sourceWidth / (sourceHeight * 1.0);

    if (canvansRadius > sourceRadius) {
        scale = [[MediaFloat alloc] initWithXValue:cgaffineTransform andYValue:1];
    } else {
        scale = [[MediaFloat alloc] initWithXValue:1 andYValue:cgaffineTransform];
    }
    return scale;
}

// ????????????
- (void)addEffects {
    
}

- (NSString *)findVideoPath:(NSString *)fileName {
// ??????????????????
    NSString *path = [[NSHomeDirectory() stringByAppendingPathComponent:@"Documents"] stringByAppendingPathComponent:@"ECC88F51-88C8-48C9-A587-1E85881AAEB9"];
    if (![[NSFileManager defaultManager] fileExistsAtPath:path]) {
        //????????????
       BOOL isSuccess =  [[NSFileManager defaultManager] createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:nil];
        if (isSuccess) {
            NSString *videoFinder = [self createVideoFinder:path];
            if (videoFinder.length > 0) {
                fileName = [videoFinder stringByAppendingPathComponent:fileName];
            }
        }
    }else {
        NSString *videoFinder = [self createVideoFinder:path];
        if (videoFinder.length > 0) {
            fileName = [videoFinder stringByAppendingPathComponent:fileName];
        }
    }
    if ([[NSFileManager defaultManager] fileExistsAtPath:fileName]) {
        NSError *error;
        [[NSFileManager defaultManager] removeItemAtPath:fileName error:&error];
    }
    return fileName;
}

- (NSString *)createVideoFinder:(NSString *)prePath {
    NSString *videoFinder = [prePath stringByAppendingPathComponent:@"video"];
    if (![[NSFileManager defaultManager] fileExistsAtPath:videoFinder]) {
        BOOL isSuccess =  [[NSFileManager defaultManager] createDirectoryAtPath:videoFinder withIntermediateDirectories:YES attributes:nil error:nil];
        if (isSuccess) {
            return videoFinder;
        } else {
            return @"";
        }
    } else {
        return videoFinder;
    }
    return @"";
}


- (void)loadAssets {
    if (self.fetchResult == nil) {
        PHFetchOptions *options = [[PHFetchOptions alloc] init];
        options.sortDescriptors = @[
            [[NSSortDescriptor alloc] initWithKey:@"creationDate" ascending:NO]
        ];
//        switch (_assetType) {
                
//            case MCPhotoPickerAssetTypePhoto:
//                options.predicate = [NSPredicate predicateWithFormat:@"mediaType = %d",PHAssetMediaTypeImage];
//                break;
//            case MCPhotoPickerAssetTypeVideo:
                options.predicate = [NSPredicate predicateWithFormat:@"mediaType = %d",PHAssetMediaTypeVideo];
//                break;
//            case MCPhotoPickerAssetTypeAll:
//                break;
//            case MCPhotoPickerAssetTypeGif: {
//                if (@available(iOS 11, *)) {
//                    PHFetchResult<PHAssetCollection *> *gifCollections = [PHAssetCollection fetchAssetCollectionsWithType:PHAssetCollectionTypeSmartAlbum subtype:PHAssetCollectionSubtypeSmartAlbumAnimated options:nil];
//                    if (gifCollections.count > 0) {
//                        _fetchResult = [PHAsset fetchAssetsInAssetCollection:gifCollections.firstObject options:nil];
//                    }
//                } else {
//
//                }
//            }
//                return;
//        }
        _fetchResult = [PHAsset fetchAssetsWithOptions:options];
        [self.collectionView reloadData];
    }
}

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath {
    CGFloat width = (self.view.frame.size.width - 4 * 20) / 3.0;
    CGFloat height = width;
    return CGSizeMake(width, height);
}

- (UIEdgeInsets)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout insetForSectionAtIndex:(NSInteger)section {
    return UIEdgeInsetsMake(0, 20, 0, 20);
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return  _fetchResult ? _fetchResult.count : 0;
}

- (__kindof UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    PHAsset *asset = [self.fetchResult objectAtIndex:indexPath.item];
    MediaChooseCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:CollectionCellIdentifier forIndexPath:indexPath];
//    NSString *filename = [asset valueForKey:@"filename"];
//    NSLog(@"name %@",filename);
    cell.representedAssetIdentifier = asset.localIdentifier;
    cell.index = indexPath.item;
    cell.imageSelected = [self.selectedAssets containsObject:asset];
//    cell.showSelectionIndex = _options.showSelectionIndex;
   
    cell.selectionIndexLabel.text = [NSString stringWithFormat:@"%lu", (unsigned long)[self.selectedAssets indexOfObject:asset] + 1];
    
    
    if (asset.mediaType == PHAssetMediaTypeVideo) {
        [cell.durationLabel setHidden:NO];
        NSInteger minutes = (NSInteger)(asset.duration / 60.0);
        NSInteger seconds = (NSInteger)round(asset.duration - 60.0 * (double)minutes);
        NSString *text = [NSString stringWithFormat:@"%02ld:%02ld", (long)minutes, (long)seconds];
        
        NSShadow *shadow = [NSShadow new];
        shadow.shadowBlurRadius = 4;
        shadow.shadowColor = [UIColor blackColor];
        shadow.shadowOffset =CGSizeMake(0,2);
        NSDictionary *attribtDic = @{NSUnderlineStyleAttributeName: [NSNumber numberWithInteger:NSUnderlineStyleNone],
                                     NSShadowAttributeName: shadow
        };
        NSMutableAttributedString *attribtStr = [[NSMutableAttributedString alloc]initWithString:text attributes:attribtDic];
        cell.durationLabel.attributedText = attribtStr;
    } else {
        [cell.durationLabel setHidden:YES];
    }

    [self.cachingImageManager requestImageForAsset:asset
                                        targetSize:self.thumbnailSize
                                       contentMode:PHImageContentModeAspectFill
                                           options:nil
                                     resultHandler:^(UIImage * _Nullable result, NSDictionary * _Nullable info) {
        if ([cell.representedAssetIdentifier isEqualToString:asset.localIdentifier] && result != nil) {
            cell.thumbnailImage = result;
        }
    }];
    
//    if (self.options.allowPreview) {
//        cell.didTapPreview = ^(NSInteger item) {
//            MCPhotoPickerAssetPreviewViewController *previewVC = [[MCPhotoPickerAssetPreviewViewController alloc] initWithAssets:self.fetchResult startIndex:(NSUInteger)item];
//            previewVC.delegate = self;
//
//            [self.navigationController pushViewController:previewVC animated:YES];
//        };
//    }
    
//    if ([[self pickerController].selectedAssets containsObject:asset]) {
//        cell.selectionIndexLabel.text = [NSString stringWithFormat:@"%lu", (unsigned long)[((NSArray *)[self pickerController].selectedAssets) indexOfObject:asset] + 1];
//        if (cell.showSelectionIndex) {
//            [cell.selectionIndexLabel setHidden:NO];
//        }
//    } else {
//        [cell.selectionIndexLabel setHidden:YES];
//    }
    
//    if (self.options.allowsHandleSelectionFromOutside) {
//        [cell.previewImageView setHidden:YES];
//    }
    
//    cell.didTapPreview = ^(NSInteger) {
//        if ([self.selectedAssets containsObject:asset]) { // ??????
//            [self.selectedAssets removeObjectAtIndex:[self.selectedAssets indexOfObject:asset]];
//            [cell.selectionIndexLabel setHidden:YES];
//            NSMutableArray<NSIndexPath *> *indexPaths = [NSMutableArray arrayWithCapacity:self.selectedAssets.count];
//            for (PHAsset *assets in self.selectedAssets) {
//                NSUInteger index = [self.fetchResult indexOfObject:assets];
//                [indexPaths addObject:[NSIndexPath indexPathForItem:index inSection:0]];
//            }
//            [UIView performWithoutAnimation:^{
//    //            [collectionView reloadData];
//                [collectionView reloadItemsAtIndexPaths:indexPaths];
//            }];
//        } else {
//            [self.selectedAssets addObject:asset]; // ??????
//            cell.selectionIndexLabel.text = [NSString stringWithFormat:@"%lu", (unsigned long)self.selectedAssets.count];
////            if (cell.showSelectionIndex) {
//                [cell.selectionIndexLabel setHidden:NO];
////            }
//        }
//
//
//        if (self.selectedAssets.count == 0) {
//            self.bottomButton.backgroundColor = [UIColor clearColor];
//            self.bottomButton.enabled = NO;
//        } else {
//            self.bottomButton.backgroundColor = [UIColor colorWithRed:254/255.0 green:44/255.0 blue:85/255.0 alpha:1];
//            self.bottomButton.enabled = YES;
//        }
//
//        [self.chooseListView showWithSelectedImages:self.selectedAssets];
//    };
    
    __weak typeof(MediaChooseCell *)weakCell = cell;
    cell.didChooseImage = ^(NSInteger item) {
        if ([self.selectedAssets containsObject:asset]) { // ??????
            [self.selectedAssets removeObjectAtIndex:[self.selectedAssets indexOfObject:asset]];
            [weakCell.selectionIndexLabel setHidden:YES];
            NSMutableArray<NSIndexPath *> *indexPaths = [NSMutableArray arrayWithCapacity:self.selectedAssets.count];
            for (PHAsset *assets in self.selectedAssets) {
                NSUInteger index = [self.fetchResult indexOfObject:assets];
                [indexPaths addObject:[NSIndexPath indexPathForItem:index inSection:0]];
            }
            [UIView performWithoutAnimation:^{
    //            [collectionView reloadData];
                [collectionView reloadItemsAtIndexPaths:indexPaths];
            }];
        } else {
            [self.selectedAssets addObject:asset]; // ??????
            weakCell.selectionIndexLabel.text = [NSString stringWithFormat:@"%lu", (unsigned long)self.selectedAssets.count];
//            if (cell.showSelectionIndex) {
                [weakCell.selectionIndexLabel setHidden:NO];
//            }
        }
        

        if (self.selectedAssets.count == 0) {
            self.bottomButton.backgroundColor = [UIColor clearColor];
            self.bottomButton.enabled = NO;
        } else {
            self.bottomButton.backgroundColor = [UIColor colorWithRed:254/255.0 green:44/255.0 blue:85/255.0 alpha:1];
            self.bottomButton.enabled = YES;
        }

        [self.chooseListView showWithSelectedImages:self.selectedAssets];
    };

    return cell;
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    
//    PHAsset *asset = [self.fetchResult objectAtIndex:indexPath.item];

//    MediaChooseCell *cell = (MediaChooseCell *)[collectionView cellForItemAtIndexPath:indexPath];
//    cell.showSelectionIndex = YES;
//    NSMutableArray<PHAsset *> *selectedAssets = [NSMutableArray arrayWithArray:[[self pickerController].selectedAssets copy]];
//
//    if ([self.selectedAssets containsObject:asset]) { // ??????
//        [self.selectedAssets removeObjectAtIndex:[self.selectedAssets indexOfObject:asset]];
//
//        [cell.selectionIndexLabel setHidden:YES];
//
//        NSMutableArray<NSIndexPath *> *indexPaths = [NSMutableArray arrayWithCapacity:self.selectedAssets.count];
//        for (PHAsset *assets in self.selectedAssets) {
//            NSUInteger index = [self.fetchResult indexOfObject:assets];
//            [indexPaths addObject:[NSIndexPath indexPathForItem:index inSection:0]];
//        }
//        [collectionView reloadItemsAtIndexPaths:[indexPaths copy]];
//
////        if (_delegate && [_delegate respondsToSelector:@selector(assetGridViewController:didDeSelectAsset:)]) {
////            [_delegate assetGridViewController:self didDeSelectAsset:asset];
////        }
//    } else {
//        [self.selectedAssets addObject:asset]; // ??????
//
//        cell.selectionIndexLabel.text = [NSString stringWithFormat:@"%lu", (unsigned long)self.selectedAssets.count];
//        if (cell.showSelectionIndex) {
//            [cell.selectionIndexLabel setHidden:NO];
//        }
//
////        if (_delegate && [_delegate respondsToSelector:@selector(assetGridViewController:didSelectAsset:)]) {
////            [_delegate assetGridViewController:self didSelectAsset:asset];
////        }
//    }
    
    
    
    
    
}

// MARK: - UIScrollView

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    [self updateCachedAssets];
}

// MARK: - Caching

-(void)resetCachedAssets {
    [self.cachingImageManager stopCachingImagesForAllAssets];
    self.previousPreheatRect = CGRectZero;
}

- (void)updateCachedAssets {
    
    if (!self.isViewLoaded || self.view.window == nil) return;
    
    CGRect visibleRect = CGRectMake(self.collectionView.contentOffset.x,
                                    self.collectionView.contentOffset.y,
                                    self.collectionView.bounds.size.width,
                                    self.collectionView.bounds.size.height);
    CGRect preheatRect = CGRectInset(visibleRect, 0, -0.5 * visibleRect.size.height);
    
    CGFloat delta = fabs(CGRectGetMidY(preheatRect) - CGRectGetMidY(self.previousPreheatRect));
    if (delta <= self.view.bounds.size.height / 3) return;
    
    NSArray *diff = [self differencesBetweenRects:self.previousPreheatRect new:preheatRect];
    
    NSArray *addedRects = [diff firstObject];
    NSArray *removedRects = [diff lastObject];
    
    NSMutableArray<PHAsset *> *addedAssets = [NSMutableArray arrayWithCapacity:addedRects.count];
    for (id rect in addedRects) {
        NSArray<NSIndexPath *> *indexPaths = [self.collectionView indexPathsForElementsInRect:[rect CGRectValue]];
        for (NSIndexPath *indexPath in indexPaths) {
            [addedAssets addObject:[self.fetchResult objectAtIndex:indexPath.item]];
        }
    }
    
    NSMutableArray<PHAsset *> *removedAssets = [NSMutableArray arrayWithCapacity:addedRects.count];
    for (id rect in removedRects) {
        NSArray<NSIndexPath *> *indexPaths = [self.collectionView indexPathsForElementsInRect:[rect CGRectValue]];
        for (NSIndexPath *indexPath in indexPaths) {
            [removedAssets addObject:[self.fetchResult objectAtIndex:indexPath.item]];
        }
    }
    
    [self.cachingImageManager startCachingImagesForAssets:[addedAssets copy] targetSize:self.thumbnailSize contentMode:PHImageContentModeAspectFill options:nil];
    [self.cachingImageManager stopCachingImagesForAssets:[removedAssets copy] targetSize:self.thumbnailSize contentMode:PHImageContentModeAspectFill options:nil];
    
    _previousPreheatRect = preheatRect;
}

- (NSArray *)differencesBetweenRects:(CGRect)old new:(CGRect)new {
    if (CGRectIntersectsRect(old, new)) {
        NSMutableArray *added = [NSMutableArray array];
        
        if (CGRectGetMaxY(new) > CGRectGetMaxY(old)) {
            [added addObject:@( CGRectMake(new.origin.x,
                                           CGRectGetMaxY(old),
                                           new.size.width,
                                           CGRectGetMaxY(new) - CGRectGetMaxY(old)) )];
        }
        
        if (CGRectGetMinY(old) > CGRectGetMinY(new)) {
            [added addObject:@( CGRectMake(new.origin.x,
                                           CGRectGetMinY(old),
                                           new.size.width,
                                           CGRectGetMinY(old) - CGRectGetMinY(new)) )];
        }
        
        NSMutableArray *removed = [NSMutableArray array];
        
        if (CGRectGetMaxY(new) < CGRectGetMaxY(old)) {
            [added addObject:@( CGRectMake(new.origin.x,
                                           CGRectGetMaxY(new),
                                           new.size.width,
                                           CGRectGetMaxY(old) - CGRectGetMaxY(new)) )];
        }
        
        if (CGRectGetMinY(old) < CGRectGetMinY(new)) {
            [added addObject:@( CGRectMake(new.origin.x,
                                           CGRectGetMinY(new),
                                           new.size.width,
                                           CGRectGetMinY(new) - CGRectGetMinY(old)) )];
        }
        
        return @[[added copy], [removed copy]];
    } else {
        return @[@[@(new)], @[@(old)]];
    }
}


// MARK: - Caching


// MARK: - Lazy

- (PHCachingImageManager *)cachingImageManager {
    if (!_cachingImageManager) {
        _cachingImageManager = [[PHCachingImageManager alloc] init];
    }
    return _cachingImageManager;
}




@end
