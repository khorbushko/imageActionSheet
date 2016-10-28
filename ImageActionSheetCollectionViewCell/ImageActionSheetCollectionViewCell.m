//
//  ImageActionSheetCollectionViewCell.m
//  
//
//  Created by Kirill Gorbushko on 20.11.15.
//  Copyright © 2015 - present thinkmobiles. All rights reserved.
//

#import "ImageActionSheetCollectionViewCell.h"

@implementation ImageActionSheetCollectionViewCell

#pragma mark - LifeCycle

- (void)prepareForReuse
{
    [super prepareForReuse];
    
    self.thumbnailImage.image = nil;
}

@end
