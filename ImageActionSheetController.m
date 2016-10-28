//
//  ImageActionSheetController
//  
//
//  Created by Kirill Gorbushko on 20.11.15.
//  Copyright © 2015 - present thinkmobiles. All rights reserved.
//

#define ActiveWidth [UIScreen mainScreen].bounds.size.width - 2 * ButtonsVerticalOffset * 2

#import "ImageActionSheetController.h"
#import "ImageActionSheetCollectionViewCell.h"

#import <Photos/Photos.h>

#import "OtremaLogoView.h"

static CGFloat const ButtonHeight = 50.f;
static CGFloat const CollectionViewHeight = 120.f;
static CGFloat const ButtonsVerticalOffset = 4.f;
static CGFloat const CornerRadius = 8.f;
static CGFloat const ImageActionSheetAnimationDuration = 0.2f;

static NSUInteger const ErrorCode = 10000;
static NSString *const RestrinctedErrorDescription = @"This application is not authorized to access photo data.";
static NSString *const DeniedErrorDescription = @"User has explicitly denied this application access to photos data.";

static NSString *const CancelButtonDefaultTitle = @"Cancel";
static NSString *const ViewPhotosDefaultTitle = @"Photo Library";
static NSString *const TakePhotoDefaultTitle = @"Take Photo";

@interface ImageActionSheetController()

@property (strong, nonatomic, nonnull) UIView *contentView;
@property (strong, nonatomic, nonnull) UIVisualEffectView *cancelButtonParentView;
@property (strong, nonatomic, nonnull) UIVisualEffectView *otherButtonsParentView;

@property (strong, nonatomic, nonnull) NSMutableArray <UIButton *> *buttons;
@property (strong, nonatomic, nonnull) NSMutableDictionary <NSString*, id> *handlers;

@property (strong, nonatomic, nullable) UICollectionView *collectionView;

@property (assign, nonatomic) CGRect previousPreheatRect;
@property (strong, nonatomic, nonnull) PHFetchResult *assetsFetchResults;
@property (strong, nonatomic, nonnull) PHCachingImageManager *imageManager;

@property (strong, nonatomic, nullable) UIImage *selectedImage;
@property (assign, nonatomic, nullable) UIButton *completionSender;
@property (assign, nonatomic) BOOL closeButtonCancel;

@end

static CGSize AssetGridThumbnailSize;

@implementation ImageActionSheetController

#pragma mark - Init

- (nonnull instancetype)initWithCancelButtonTitle:(nonnull NSString *)cancelButtonTitle
                          photoPreviewButtonTitle:(nonnull NSString *)photoPreviewButtonTitle
                             takePhotoButtonTitle:(nonnull NSString *)takePhotoButtonTitle
{
    self = [self initWithCancelButtonTitle:cancelButtonTitle photoPreviewButtonTitle:photoPreviewButtonTitle];
    if (self) {
        NSParameterAssert(takePhotoButtonTitle);

        self.takePhotoButtonTitle = takePhotoButtonTitle;
    }
    return self;
}

- (nonnull instancetype)initWithCancelButtonTitle:(nonnull NSString *)cancelButtonTitle
                          photoPreviewButtonTitle:(nonnull NSString *)photoPreviewButtonTitle
{
    self = [self init];

    if (self) {
        NSParameterAssert(photoPreviewButtonTitle);
        NSParameterAssert(cancelButtonTitle);
        
        self.cancelButtonTitle = cancelButtonTitle.length ? cancelButtonTitle : CancelButtonDefaultTitle;
        self.photoPreviewButtonTitle = photoPreviewButtonTitle.length ? photoPreviewButtonTitle : ViewPhotosDefaultTitle;
    }
    return self;
}

- (nonnull instancetype)init
{
    self = [super init];
    if (self) {
        self.previousPreheatRect = CGRectZero;
        self.showTakePhotoButton = YES;
        
        self.buttons = [[NSMutableArray alloc] init];
        self.handlers = [[NSMutableDictionary alloc] init];

        self.tintColor = [UIColor colorWithRed:0 green:122/255.f blue:1 alpha:1];
        self.cancelButtonTintColor = [[UIColor redColor] colorWithAlphaComponent:0.8f];
        self.buttonFont = [UIFont systemFontOfSize:18.f];
        
        self.cancelButtonTitle = CancelButtonDefaultTitle;
        self.photoPreviewButtonTitle = ViewPhotosDefaultTitle;
        self.takePhotoButtonTitle = TakePhotoDefaultTitle;
        
        self.modalPresentationStyle = UIModalPresentationOverCurrentContext;
        self.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
    }
    return self;
}

#pragma mark - LifeCycle

- (void)viewDidLoad
{
    [super viewDidLoad];

    [OtremaLogoView configureOtremaLogoOnView:self.view withColor:[UIColor whiteColor]];
    [self prepareView];
    
    [self resetCachedAssets];
    [self requestAllPhotos];
    
    [self configureCancelButtonView];
    [self configureOtherButtonView];
    [self prepareContainer];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    [self prepareTargetSize];
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    
    if (!self.contentView.layer.animationKeys.count) {
        [self animatePosition];
    }
}

#pragma mark - Public

- (void)addButtonWithTitle:(nonnull NSString *)title completionHandler:(void (^ _Nonnull)())completionHadler
{
    NSParameterAssert(title);
    NSParameterAssert(completionHadler);

    if (title.length && completionHadler) {
        UIButton *button = [[UIButton alloc] init];
        [button setTitle:title forState:UIControlStateNormal];
        [button addTarget:self action:@selector(customButtonAction:) forControlEvents:UIControlEventTouchUpInside];
        [self.buttons addObject:button];
        
        void (^handlerCopy)() = [completionHadler copy];
        NSParameterAssert(handlerCopy);
        
        [self.handlers setObject:handlerCopy forKey:[self keyForButton:button]];
    }
}

- (void)requestAuthorizationToPhotos
{
    __weak typeof(self) weakSelf = self;
    [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus status) {
        __strong __typeof(weakSelf) strongSelf = weakSelf;
        dispatch_async(dispatch_get_main_queue(), ^{
            switch (status) {
                case PHAuthorizationStatusAuthorized: {
                    [strongSelf prepareCameraRollImages];
                    [strongSelf.collectionView reloadData];
                    break;
                }
                case PHAuthorizationStatusDenied:
                case PHAuthorizationStatusRestricted: {
                    if (strongSelf.delegate && [strongSelf.delegate respondsToSelector:@selector(imageActionSheetControllerDidReceiveError:)]) {
                        [strongSelf.delegate imageActionSheetControllerDidReceiveError:[strongSelf errorWithDescription:status == PHAuthorizationStatusRestricted ? RestrinctedErrorDescription : DeniedErrorDescription]];
                    }
                    break;
                }
                default:
                    break;
            }
        });
    }];
}

+ (void)requestAuthorizationToPhotos
{
    [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus status) {
        
    }];
}

#pragma mark - Actions

- (void)cancelButtonTapped:(UIButton *)sender
{
    self.closeButtonCancel = YES;
    self.completionSender = nil;
    [self dismissAnimation];
}

- (void)customButtonAction:(UIButton *)sender
{
    self.completionSender = sender;
    self.closeButtonCancel = NO;
    [self dismissAnimation];
}

- (void)selectPhotoButtonTapped:(UIButton *)sender
{
    if (self.photoSelectionButtonDidTapped) {
        self.completionSender = nil;
        self.closeButtonCancel = NO;
        [self dismissAnimation];
    } else {
        [self animatedViewHide];
        [self presentImagePickerController:YES];
    }
}

- (void)takeImageButtonTapped:(UIButton *)sender
{
    [self animatedViewHide];
    [self presentImagePickerController:NO];
}

- (void)callHandlerForButton:(UIButton *)sender
{
    void (^handler)() = [self.handlers objectForKey:[self keyForButton:sender]];
    if (handler) {
        handler();
    }
}

#pragma mark - UICollectionViewDelegate

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
    collectionView.allowsSelection = NO;
    __weak typeof(self) weakSelf = self;
    [self.imageManager requestImageForAsset:self.assetsFetchResults[indexPath.row] targetSize:PHImageManagerMaximumSize contentMode:PHImageContentModeAspectFit options:nil resultHandler:^(UIImage *result, NSDictionary *info) {
        __strong __typeof(weakSelf) strongSelf = weakSelf;
        dispatch_async(dispatch_get_main_queue(), ^{
            strongSelf.selectedImage = result;
            [strongSelf dismissAnimation];
        });
    }];
}

#pragma mark - UICollectionViewDataSource

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
    return self.assetsFetchResults.count;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    ImageActionSheetCollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:NSStringFromClass([ImageActionSheetCollectionViewCell class]) forIndexPath:indexPath];
    if (!cell) {
        cell = [[ImageActionSheetCollectionViewCell alloc] init];
    }
    [self configureCell:cell atIndexPath:indexPath];
    return cell;
}

#pragma mark - UICollectionViewDelegateFlowLayout

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath
{
    CGFloat heightOfImage = self.collectionView.frame.size.height;
    PHAsset *cellAsset = self.assetsFetchResults[indexPath.row];
    CGSize imageSize =  CGSizeMake(cellAsset.pixelWidth, cellAsset.pixelHeight);
    CGFloat koef = imageSize.height / heightOfImage;
    
    return CGSizeMake(imageSize.width / koef, heightOfImage);
}

- (CGFloat)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout minimumInteritemSpacingForSectionAtIndex:(NSInteger)section
{
    return 8;
}

#pragma mark - UIScrollViewDelegate

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    [self updateCachedAssets];
}

#pragma mark - Private

#pragma mark - Preparation

- (void)configureCell:(ImageActionSheetCollectionViewCell *)cell atIndexPath:(NSIndexPath *)indexPath
{
    [self.imageManager requestImageForAsset:self.assetsFetchResults[indexPath.row] targetSize:AssetGridThumbnailSize contentMode:PHImageContentModeAspectFit options:nil resultHandler:^(UIImage *result, NSDictionary *info) {
        dispatch_async(dispatch_get_main_queue(), ^{
            cell.thumbnailImage.image = result;
        });
    }];
}

- (NSString *)keyForButton:(UIButton *)button
{
    return [NSString stringWithFormat: @"%p", button];
}

- (void)prepareView
{
    self.view.backgroundColor = [[UIColor lightGrayColor] colorWithAlphaComponent:0.85f];
}

- (void)prepareContainer
{
    CGFloat screenWidth = [UIScreen mainScreen].bounds.size.width;
    CGFloat offset = ButtonsVerticalOffset * 2;
    CGFloat contentHeight = self.cancelButtonParentView.frame.size.height + ButtonsVerticalOffset * 3 + self.otherButtonsParentView.frame.size.height;

    self.contentView = [[UIView alloc] initWithFrame:CGRectMake(offset, 0, screenWidth, contentHeight)];
    CGFloat currentYposition = CGRectGetMaxY(self.contentView.bounds) - ButtonsVerticalOffset;

    CGRect cancelButtonViewFrame = self.cancelButtonParentView.frame;
    cancelButtonViewFrame.origin.y = currentYposition - CGRectGetHeight(cancelButtonViewFrame);
    self.cancelButtonParentView.frame = cancelButtonViewFrame;
    
    CGRect otherButtonsViewFrame = self.otherButtonsParentView.frame;
    otherButtonsViewFrame.origin.y = ButtonsVerticalOffset;
    self.otherButtonsParentView.frame = otherButtonsViewFrame;

    [self.contentView addSubview:self.otherButtonsParentView];
    [self.contentView addSubview:self.cancelButtonParentView];

    [self.view addSubview:self.contentView];
}

- (void)configureCancelButtonView
{
    self.cancelButtonParentView = [self visualEffectViewFrame:CGRectMake(ButtonsVerticalOffset * 2, 0, ActiveWidth, ButtonHeight)];
    self.cancelButtonParentView.layer.cornerRadius = CornerRadius;
    self.cancelButtonParentView.layer.masksToBounds = YES;
    self.cancelButtonParentView.effect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleExtraLight];
    
    UIButton *cancelButton = [[UIButton alloc] initWithFrame:self.cancelButtonParentView.bounds];
    [cancelButton setTitle:self.cancelButtonTitle forState:UIControlStateNormal];
    [cancelButton addTarget:self action:@selector(cancelButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
    [cancelButton setTitleColor:self.cancelButtonTintColor forState:UIControlStateNormal];
    [cancelButton.titleLabel setFont:[UIFont boldSystemFontOfSize:18.f]];
    
    [self.cancelButtonParentView.contentView addSubview:cancelButton];
}

- (void)configureOtherButtonView
{
    CGFloat heighForOtherButtonView = self.buttons.count * ButtonHeight + self.buttons.count + (self.showTakePhotoButton ? ButtonHeight : 0);
    if (self.photoPreviewButtonTitle.length) {
        heighForOtherButtonView += ButtonHeight + CollectionViewHeight + ButtonsVerticalOffset;
    }
    
    self.otherButtonsParentView = [self visualEffectViewFrame:CGRectMake(ButtonsVerticalOffset * 2, 0, ActiveWidth, heighForOtherButtonView)];
    
    CGFloat currentYposition = CGRectGetMaxY(self.otherButtonsParentView.frame);
    if (self.showTakePhotoButton) {
        currentYposition -= (ButtonHeight + 1);
        [self addTakePhotoButton];
    }
    
    for (int i = 0; i < self.buttons.count; i++) {
        
        UIButton *otherButton = (UIButton *)self.buttons[i];
        otherButton.frame = CGRectMake(0, currentYposition - ButtonHeight, self.otherButtonsParentView.bounds.size.width, ButtonHeight);
        currentYposition -= ButtonHeight;
        [otherButton setTitleColor:self.tintColor forState:UIControlStateNormal];
        [otherButton.titleLabel setFont:self.buttonFont];
        
        [self.otherButtonsParentView.contentView addSubview:otherButton];
        
        if (i < (self.buttons.count + (self.photoPreviewButtonTitle.length ? 1 : 0)) - 1) {
            UIView *separator = [self separatorView];
            CGRect separatorFrame = separator.frame;
            separatorFrame.origin.y = currentYposition - separatorFrame.size.height;
            separator.frame = separatorFrame;
            
            [self.otherButtonsParentView.contentView addSubview:separator];
            currentYposition -= separatorFrame.size.height;
        }
    }
    
    if (self.photoPreviewButtonTitle.length) {
        UIButton *photoButton = [[UIButton alloc] initWithFrame:CGRectMake(0, 0, ActiveWidth, ButtonHeight + CollectionViewHeight)];
        [photoButton setTitle:self.photoPreviewButtonTitle forState:UIControlStateNormal];
        [photoButton addTarget:self action:@selector(selectPhotoButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
        photoButton.frame = CGRectMake(0, currentYposition - ButtonHeight, self.otherButtonsParentView.bounds.size.width, ButtonHeight);
        [photoButton setTitleColor:self.tintColor forState:UIControlStateNormal];
        [photoButton.titleLabel setFont:self.buttonFont];
        
        [self.otherButtonsParentView.contentView addSubview:photoButton];
        
        [self prepareCollectionView];
    }
}

- (void)addTakePhotoButton
{
    UIButton *takePhotoButton = [[UIButton alloc] init];
    takePhotoButton.frame = CGRectMake(0, CGRectGetMaxY(self.otherButtonsParentView.frame) - ButtonHeight, self.otherButtonsParentView.bounds.size.width, ButtonHeight);
    NSString *title = self.takePhotoButtonTitle.length ? self.takePhotoButtonTitle : TakePhotoDefaultTitle;
    [takePhotoButton setTitle:title forState:UIControlStateNormal];
    [takePhotoButton setTitleColor:self.tintColor forState:UIControlStateNormal];
    [takePhotoButton addTarget:self action:@selector(takeImageButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
    [takePhotoButton.titleLabel setFont:self.buttonFont];
    
    [self.otherButtonsParentView.contentView addSubview:takePhotoButton];
    
    UIView *separator = [self separatorView];
    CGRect separatorFrame = separator.frame;
    separatorFrame.origin.y = CGRectGetMaxY(self.otherButtonsParentView.frame) - ButtonHeight - separatorFrame.size.height;
    separator.frame = separatorFrame;
    
    [self.otherButtonsParentView.contentView addSubview:separator];
}

- (void)prepareCollectionView
{
    UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
    layout.scrollDirection = UICollectionViewScrollDirectionHorizontal;
    self.collectionView = [[UICollectionView alloc] initWithFrame:CGRectMake(0, ButtonsVerticalOffset, ActiveWidth, CollectionViewHeight) collectionViewLayout:layout];
    self.collectionView.backgroundColor = [UIColor clearColor];
    self.collectionView.delegate = self;
    self.collectionView.dataSource = self;
    self.collectionView.showsHorizontalScrollIndicator = NO;
    [self.collectionView registerNib:[UINib nibWithNibName:NSStringFromClass([ImageActionSheetCollectionViewCell class]) bundle:nil] forCellWithReuseIdentifier:NSStringFromClass([ImageActionSheetCollectionViewCell class])];

    [self.otherButtonsParentView.contentView addSubview:self.collectionView];
}

- (UIView *)separatorView
{
    UIView *separator = [[UIView alloc] initWithFrame:CGRectMake(0, 0, [UIScreen mainScreen].bounds.size.width - 2 * ButtonsVerticalOffset * 2, .75f)];
    separator.backgroundColor = [[UIColor lightGrayColor] colorWithAlphaComponent:0.5f];
    return separator;
}

- (UIVisualEffectView *)visualEffectViewFrame:(CGRect)rect
{
    UIVisualEffectView *veView = [[UIVisualEffectView alloc] initWithFrame:rect];
    veView.layer.cornerRadius = CornerRadius;
    veView.layer.masksToBounds = YES;
    veView.effect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleExtraLight];

    return veView;
}

#pragma mark - ImagePicker

- (void)presentImagePickerController:(BOOL)selectImage
{
	UIImagePickerControllerSourceType sourceType = selectImage ? UIImagePickerControllerSourceTypePhotoLibrary : UIImagePickerControllerSourceTypeCamera;
	
	if ((sourceType == UIImagePickerControllerSourceTypeCamera) && ![UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera]) {
		[self cancelButtonTapped:nil];		
		return;
	}
	
	UIImagePickerController *picker = [[UIImagePickerController alloc] init];
	picker.delegate = self;
	picker.allowsEditing = YES;
	picker.sourceType = sourceType;
    
    [self presentViewController:picker animated:YES completion:NULL];
}

#pragma mark - UIImagePickerControllerDelegate

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info
{
    self.selectedImage = info[UIImagePickerControllerEditedImage];
    [picker dismissViewControllerAnimated:YES completion:nil];
    
    __weak typeof(self) weakSelf = self;
    [self dismissViewControllerAnimated:NO completion:^{
        __strong __typeof(weakSelf) strongSelf = weakSelf;
        if (picker.sourceType == UIImagePickerControllerSourceTypePhotoLibrary) {
            if (strongSelf.delegate && [strongSelf.delegate respondsToSelector:@selector(imageActionSheetControllerDidSelectImageWithPicker:)]) {
                [strongSelf.delegate imageActionSheetControllerDidSelectImageWithPicker:strongSelf.selectedImage];
            }
        } else if (picker.sourceType == UIImagePickerControllerSourceTypeCamera){
            if (strongSelf.delegate && [strongSelf.delegate respondsToSelector:@selector(imageActionSheetControllerDidTakeImageWithPicker:)]) {
                [strongSelf.delegate imageActionSheetControllerDidTakeImageWithPicker:strongSelf.selectedImage];
            }
        }
    }];
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker
{
    self.view.layer.opacity = 1.f;
    [picker dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - Photos 

- (void)requestAllPhotos
{
    if ([PHPhotoLibrary authorizationStatus] == PHAuthorizationStatusAuthorized) {
        [self prepareCameraRollImages];
    } else {
        [self requestAuthorizationToPhotos];
    }
}

- (void)prepareCameraRollImages
{
    self.imageManager = [[PHCachingImageManager alloc] init];
    PHFetchOptions *allPhotosOptions = [PHFetchOptions new];
    allPhotosOptions.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"creationDate" ascending:self.sortPhotosOrderAscendingByDate]];
    self.assetsFetchResults = [PHAsset fetchAssetsWithMediaType:PHAssetMediaTypeImage options:allPhotosOptions];
}

- (void)prepareTargetSize
{
    CGFloat scale = [UIScreen mainScreen].scale;
    CGSize cellSize = ((UICollectionViewFlowLayout *)self.collectionView.collectionViewLayout).itemSize;
    AssetGridThumbnailSize = CGSizeMake(cellSize.width * scale * 2, cellSize.height * scale * 2);
}

- (void)resetCachedAssets
{
    [self.imageManager stopCachingImagesForAllAssets];
    self.previousPreheatRect = CGRectZero;
}

- (void)updateCachedAssets
{
    BOOL isViewVisible = [self isViewLoaded] && [[self view] window] != nil;
    if (!isViewVisible) {
        return;
    }
    
    CGRect preheatRect = self.collectionView.bounds;
    preheatRect = CGRectInset(preheatRect, 0.0f, -0.5f * CGRectGetHeight(preheatRect));
    
    CGFloat delta = ABS(CGRectGetMidY(preheatRect) - CGRectGetMidY(self.previousPreheatRect));
    if (delta > CGRectGetHeight(self.collectionView.bounds) / 3.0f) {
        NSMutableArray *addedIndexPaths = [NSMutableArray array];
        NSMutableArray *removedIndexPaths = [NSMutableArray array];
        
        [self computeDifferenceBetweenRect:self.previousPreheatRect andRect:preheatRect removedHandler:^(CGRect removedRect) {
            NSArray *indexPaths = [self indexPathsForElementsInRect:removedRect];
            [removedIndexPaths addObjectsFromArray:indexPaths];
        } addedHandler:^(CGRect addedRect) {
            NSArray *indexPaths = [self indexPathsForElementsInRect:addedRect];
            [addedIndexPaths addObjectsFromArray:indexPaths];
        }];
        
        NSArray *assetsToStartCaching = [self assetsAtIndexPaths:addedIndexPaths];
        NSArray *assetsToStopCaching = [self assetsAtIndexPaths:removedIndexPaths];
        
        [self.imageManager startCachingImagesForAssets:assetsToStartCaching targetSize:AssetGridThumbnailSize contentMode:PHImageContentModeAspectFit options:nil];
        [self.imageManager stopCachingImagesForAssets:assetsToStopCaching targetSize:AssetGridThumbnailSize contentMode:PHImageContentModeAspectFit options:nil];
        
        self.previousPreheatRect = preheatRect;
    }
}

- (NSArray *)indexPathsForElementsInRect:(CGRect)rect
{
    NSArray *allLayoutAttributes = [self.collectionView.collectionViewLayout layoutAttributesForElementsInRect:rect];
    if (!allLayoutAttributes.count) {
        return nil;
    }
    NSMutableArray *indexPaths = [NSMutableArray arrayWithCapacity:allLayoutAttributes.count];
    for (UICollectionViewLayoutAttributes *layoutAttributes in allLayoutAttributes) {
        NSIndexPath *indexPath = layoutAttributes.indexPath;
        [indexPaths addObject:indexPath];
    }
    return indexPaths;
}

- (NSArray *)assetsAtIndexPaths:(NSArray *)indexPaths
{
    if (!indexPaths.count) {
        return nil;
    }
    
    NSMutableArray *assets = [NSMutableArray arrayWithCapacity:indexPaths.count];
    for (NSIndexPath *indexPath in indexPaths) {
        PHAsset *asset = self.assetsFetchResults[indexPath.item];
        [assets addObject:asset];
    }
    
    return assets;
}

- (void)computeDifferenceBetweenRect:(CGRect)oldRect andRect:(CGRect)newRect removedHandler:(void (^)(CGRect removedRect))removedHandler addedHandler:(void (^)(CGRect addedRect))addedHandler
{
    if (CGRectIntersectsRect(newRect, oldRect)) {
        CGFloat oldMaxY = CGRectGetMaxY(oldRect);
        CGFloat oldMinY = CGRectGetMinY(oldRect);
        CGFloat newMaxY = CGRectGetMaxY(newRect);
        CGFloat newMinY = CGRectGetMinY(newRect);
        
        if (newMaxY > oldMaxY) {
            CGRect rectToAdd = CGRectMake(newRect.origin.x, oldMaxY, newRect.size.width, (newMaxY - oldMaxY));
            addedHandler(rectToAdd);
        }
        
        if (oldMinY > newMinY) {
            CGRect rectToAdd = CGRectMake(newRect.origin.x, newMinY, newRect.size.width, (oldMinY - newMinY));
            addedHandler(rectToAdd);
        }
        
        if (newMaxY < oldMaxY) {
            CGRect rectToRemove = CGRectMake(newRect.origin.x, newMaxY, newRect.size.width, (oldMaxY - newMaxY));
            removedHandler(rectToRemove);
        }
        
        if (oldMinY < newMinY) {
            CGRect rectToRemove = CGRectMake(newRect.origin.x, oldMinY, newRect.size.width, (newMinY - oldMinY));
            removedHandler(rectToRemove);
        }
    } else {
        addedHandler(newRect);
        removedHandler(oldRect);
    }
}

#pragma mark - Error

- (NSError *)errorWithDescription:(NSString *)description
{
    return [NSError errorWithDomain:NSStringFromClass([self class])
                               code:ErrorCode userInfo:@{
                                                         NSLocalizedDescriptionKey : description,
                                                         NSLocalizedRecoverySuggestionErrorKey : @"Please enable access to photos"
                                                         }];
}

#pragma mark - Animations

- (void)animatePosition
{
    CABasicAnimation *position = [CABasicAnimation animationWithKeyPath:@"position"];
    CGPoint fromPoint = CGPointMake(self.view.center.x, self.view.center.x + self.view.frame.size.height);
    position.fromValue = [NSValue valueWithCGPoint:fromPoint];
    
    CGFloat screenHeight = [UIScreen mainScreen].bounds.size.height;
    CGFloat toPointY = screenHeight - self.contentView.frame.size.height / 2;
    CGFloat toPointX = [UIScreen mainScreen].bounds.size.width / 2;
    CGPoint toPoint = CGPointMake(toPointX, toPointY);
    
    position.toValue = [NSValue valueWithCGPoint:toPoint];
    position.duration = ImageActionSheetAnimationDuration;
    [self.contentView.layer addAnimation:position forKey:@"positioning"];
    self.contentView.layer.position = toPoint;
}

- (void)dismissAnimation
{
    CABasicAnimation *dismissAnimation = [CABasicAnimation animationWithKeyPath:@"position"];
    dismissAnimation.fromValue = [NSValue valueWithCGPoint:self.contentView.center];
    
    CGPoint endPoint = CGPointMake(self.contentView.center.x, self.contentView.center.y + self.contentView.frame.size.height);
    
    dismissAnimation.toValue = [NSValue valueWithCGPoint:endPoint];
    dismissAnimation.duration = ImageActionSheetAnimationDuration;
    dismissAnimation.delegate = self;
    dismissAnimation.removedOnCompletion = NO;
    
    CABasicAnimation *opacityAnimation = [CABasicAnimation animationWithKeyPath:@"opacity"];
    opacityAnimation.fromValue = @(1);
    opacityAnimation.toValue = @(0);
    opacityAnimation.duration = ImageActionSheetAnimationDuration;
    opacityAnimation.removedOnCompletion = NO;
    
    [self.view.layer addAnimation:opacityAnimation forKey:nil];
    self.view.layer.opacity = 0.f;
    
    [self.contentView.layer addAnimation:dismissAnimation forKey:@"dismissAnimations"];
    self.contentView.layer.position = endPoint;
}

- (void)animatedViewHide
{
    CABasicAnimation *opacityAnimation = [CABasicAnimation animationWithKeyPath:@"opacity"];
    opacityAnimation.fromValue = @(1);
    opacityAnimation.toValue = @(0);
    opacityAnimation.duration = ImageActionSheetAnimationDuration;
    opacityAnimation.removedOnCompletion = NO;
    
    [self.view.layer addAnimation:opacityAnimation forKey:nil];
    self.view.layer.opacity = 0.f;
}

#pragma mark - AnimationDelegate

- (void)animationDidStop:(CAAnimation *)anim finished:(BOOL)flag
{
    if (anim == [self.contentView.layer animationForKey:@"dismissAnimations"]) {
        [self.contentView.layer removeAllAnimations];
        
        __weak typeof(self) weakSelf = self;

        if (self.closeButtonCancel) {
            [self dismissViewControllerAnimated:NO completion:nil];
        } else {
            [self dismissViewControllerAnimated:NO completion:^{
                __strong __typeof(weakSelf) strongSelf = weakSelf;
                if (strongSelf.selectedImage  && strongSelf.photoDidSelectImageInPreview) {
                    strongSelf.photoDidSelectImageInPreview(strongSelf.selectedImage);
                } else if (strongSelf.completionSender) {
                    [strongSelf callHandlerForButton:strongSelf.completionSender];
                } else  if (strongSelf.photoSelectionButtonDidTapped){
                    strongSelf.photoSelectionButtonDidTapped();
                }
            }];
        }
    }
}

#pragma mark - Touch

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    CGPoint touchLocation = [[touches anyObject] locationInView:self.view];

    if (![self.contentView pointInside:[self.view convertPoint:touchLocation toView:self.contentView] withEvent:event] && !self.presentedViewController) {
        self.closeButtonCancel = YES;
        self.completionSender = nil;
        [self dismissAnimation];
    }
}

@end