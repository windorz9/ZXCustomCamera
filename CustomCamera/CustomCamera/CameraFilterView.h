//
//  CameraFilterView.h
//  CustomCamera
//
//  Created by 张雄 on 2018/5/16.
//  Copyright © 2018年 张雄. All rights reserved.
//

#import <UIKit/UIKit.h>
@protocol CameraFilterViewDelegate <NSObject>

- (void)switchCameraFilter:(NSInteger)index;//滤镜选择方法

@end

@interface CameraFilterView : UICollectionView<UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout>
@property (strong, nonatomic) NSMutableArray *picArray;//图片数组
@property (strong, nonatomic) id <CameraFilterViewDelegate> cameraFilterDelegate;


@end
