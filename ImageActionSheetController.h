//
//  ImageActionSheetController
//  
//
//  Created by Kirill Gorbushko on 20.11.15.
//  Copyright © 2015 - present thinkmobiles. All rights reserved.
//

#import <UIKit/UIKit.h>

/*!
 @protocol ImageActionSheetControllerDelegate
 @discussion Use this Protocol for receiving information about
 events while working with ImageActionSheetController
 @availability iOS 8 and Later
 */
@protocol ImageActionSheetControllerDelegate <NSObject>

@optional
/*!
 Return an error if cant get access to user photos
 @param error
 Describe reason why we cant get user photos
 */
- (void)imageActionSheetControllerDidReceiveError:(NSError * _Nonnull)error;

/*!
 Return an image that was selected from UIIMagePickerController
 @param image
 Selected image
 */
- (void)imageActionSheetControllerDidSelectImageWithPicker:(UIImage * _Nonnull)image;

/*!
 Return an image that was taked from camera with UIIMagePickerController
 required if showTakePhotoButton = YES (by default)
 @param image
 Selected image
 */
- (void)imageActionSheetControllerDidTakeImageWithPicker:(UIImage * _Nonnull)image;

@end

/*!
 @class ImageActionSheetController
 @discussion This class can be used as actionSheet with
 possibility to display and select photo from CameraRoll
 This class require to use Photos.framework
 After creating this object use it as normal ViewController like in
 following example:
 @code 
     ImageActionSheetController *action = [[ImageActionSheetController alloc] initWithCancelButtonTitle:@"Cancel" photoPreviewButtonTitle:@"Photo Library"];
     [action addButtonWithTitle:@"Test" completionHandler:^{
     //some action
     }];
     action.photoDidSelectImageInPreview = ^(UIImage *selectdImage) {
     //some action
     };
     [self presentViewController:action animated:YES completion:nil];
 @endcode
 @availability iOS 8 and later
*/
@interface ImageActionSheetController : UIViewController <UICollectionViewDataSource, UICollectionViewDelegate, UIScrollViewDelegate, UICollectionViewDelegateFlowLayout, UIImagePickerControllerDelegate, UINavigationControllerDelegate>

/*!
@var delegate
@abstract The delegate object you want to receive events from ImageActionSheetController
@discussion Use this object to receive messages from ImageActionSheetController.
 */
@property (weak, nonatomic, nullable) id <ImageActionSheetControllerDelegate> delegate;

/*!
 @var sortPhotosOrderAscendingByDate
 @abstract boolean value that indicate whereever images from CameraRoll should be sorted and displayed by creatingDate in Ascending or Descending way
 */
@property (assign, nonatomic) BOOL sortPhotosOrderAscendingByDate;

/*!
 @var showTakePhotoButton
 @abstract boolean value that indicate whereever to show or no "Take Photo Button" default to YES 
 */
@property (assign, nonatomic) BOOL showTakePhotoButton;

/*!
 @var buttonFont
 @abstract font for all button, default [UIFont systemFontOfSize:18.f];
 */
@property (strong, nonatomic, nullable) UIFont *buttonFont;
/*!
 @var tintColor
 @abstract tint color for all button, default [[UIColor blueColor] colorWithAlphaComponent:0.8f]
 */
@property (strong, nonatomic, nullable) UIColor *tintColor;
/*!
 @var cancelButtonTintColor
 @abstract tint color for cancel button, default [[UIColor redColor] colorWithAlphaComponent:0.8f]
 */
@property (strong, nonatomic, nullable) UIColor *cancelButtonTintColor;

/*!
 @var cancelButtonTitle
 @abstract allow to update Cancel button title, default value - "Cancel", also seted when create object
 */
@property (copy, nonatomic, nullable) NSString *cancelButtonTitle;
/*!
 @var photoPreviewButtonTitle
 @abstract allow to update ViewPhotos button title, default value - "Photo Library", also seted when create object
 */
@property (copy, nonatomic, nullable) NSString *photoPreviewButtonTitle;
/*!
 @var takePhotoButtonTitle
 @abstract allow to update TakePhoto button title, default value - "Take Photo"
 */
@property (copy, nonatomic, nullable) NSString *takePhotoButtonTitle;

/*!
 @var photoSelectionButtonDidTapped
 @abstract handler photoPreviewButton action, if not set no default action (action sheet will be dismissed)
 */
@property (strong, nonatomic, nullable) void (^photoSelectionButtonDidTapped)();
/*!
 @var photoDidSelectImageInPreview
 @abstract handler for selection image in preview part
  image
 Return selected image with MaxPossibleSize
 */
@property (strong, nonatomic, nullable) void (^photoDidSelectImageInPreview)(UIImage * _Nonnull image);

/*!
 Use this method before creating and calling ImageActionSheetController
 This method request access to CameraRoll 
 If u not call this method before usage ImageActionSheetController access will be 
 requested during usega of ImageActionSheetController and small delay in displaying 
 photos can be possible
 */
+ (void)requestAuthorizationToPhotos;

/*!
 Create an instance of ImageActionSheetController
 @param cancelButtonTitle
 Title for cancel button (the bottom one) if not set "Cancel" will be used
 @param photoPreviewButtonTitle
 Title for default button (the bottom under collectionView with photos) 
 if not set "Photo Library" will be used
 Action for this button if not created - use delegate method imageActionSheetControllerDidSelectImageWithPicker,
 you can prepare your own action - use handler photoSelectionButtonDidTapped()
 @result
 instance of ImageActionSheetController
 */
- (nonnull instancetype)initWithCancelButtonTitle:(nonnull NSString *)cancelButtonTitle
                          photoPreviewButtonTitle:(nonnull NSString *)photoPreviewButtonTitle;

/*!
 Create an instance of ImageActionSheetController
 @param cancelButtonTitle
 Title for cancel button (the bottom one) if not set "Cancel" will be used
 @param photoPreviewButtonTitle
 Title for default button (the bottom under collectionView with photos)
 if not set "Photo Library" will be used
 Action for this button if not created - use delegate method imageActionSheetControllerDidSelectImageWithPicker, 
 you can prepare your own action - use handler photoSelectionButtonDidTapped()
 @param takePhotoButtonTitle
 Title for TakePhoto button, default "Take Photo", for getting result use delegate method imageActionSheetControllerDidTakeImageWithPicker
 @result
 instance of ImageActionSheetController
 */
- (nonnull instancetype)initWithCancelButtonTitle:(nonnull NSString *)cancelButtonTitle
                          photoPreviewButtonTitle:(nonnull NSString *)photoPreviewButtonTitle
                             takePhotoButtonTitle:(nonnull NSString *)takePhotoButtonTitle;

/*!
 Add additional action button to action sheet
 This button will be placed between TakePhoto button and Photo Library button
 @param title
 title for additional button
 @param completionHadler
 handler for action
 */
- (void)addButtonWithTitle:(nonnull NSString *)title completionHandler:(void (^ _Nonnull)())completionHadler;

@end
