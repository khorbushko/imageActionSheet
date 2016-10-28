//
//  ImageActionSheetCollectionViewCell.h
//  
//
//  Created by Kirill Gorbushko on 20.11.15.
//  Copyright © 2015 - present thinkmobiles. All rights reserved.
//

#import <UIKit/UIKit.h>

/*!
 @class ImageActionSheetCollectionViewCell
 @discussion ResizebleCell for images preview
 @availability iOS 8 and Later
 */
@interface ImageActionSheetCollectionViewCell : UICollectionViewCell

/*!
 @var thumbnailImage
 @abstract ImageView with thumbnail
 */
@property (weak, nonatomic) IBOutlet UIImageView *thumbnailImage;

@end
