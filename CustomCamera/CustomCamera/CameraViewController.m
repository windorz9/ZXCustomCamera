//
//  CameraViewController.m
//  CustomCamera
//
//  Created by 张雄 on 2018/5/16.
//  Copyright © 2018年 张雄. All rights reserved.
//

#import "CameraViewController.h"
#import <GPUImage.h>
#import "CameraFilterView.h"
#import "CheckViewController.h"
#import "MyCamera.h"
#define WIDTH [UIScreen mainScreen].bounds.size.width
#define HEIGHT [UIScreen mainScreen].bounds.size.height
static int CameraFilterCount = 9; // 滤镜的数量

// 滤镜 view 的显示状态
typedef NS_ENUM(NSUInteger, FilterViewState) {
    FilterViewHidden, // 隐藏
    FilterViewUsing // 显示
};

// 闪光灯状态
typedef NS_ENUM(NSUInteger, CameraManagerFlashMode) {
    CameraManagerFlashModeAuto, // 自动
    CameraManagerFlashModeOff, // 关闭
    CameraManagerFlashModeOn  // 打开
};

@interface CameraViewController () <UIGestureRecognizerDelegate, CameraFilterViewDelegate, CAAnimationDelegate>
{
    CALayer *_focusLayer; // 聚焦层
}

// 新建相机管理者
@property (nonatomic, strong) GPUImageStillCamera *cameraManager;
@property (strong, nonatomic) IBOutlet UIView *cameraView;
@property (weak, nonatomic) IBOutlet UIView *preview;
@property (weak, nonatomic) IBOutlet UIView *bottomView;

// 自定义滤镜
@property (nonatomic, strong) CameraFilterView *cameraFilterView;

@property (nonatomic , assign) CameraManagerFlashMode flashMode;
@property (nonatomic , assign) FilterViewState filterViewState;
@property (weak, nonatomic) IBOutlet UIButton *flashButton;

@property (nonatomic , assign) CGFloat beginGestureScale;//开始的缩放比例
@property (nonatomic , assign) CGFloat effectiveScale;//最后的缩放比例

@property (nonatomic, strong) GPUImageOutput *filter; // 滤镜
@property (nonatomic, strong) GPUImageView *filterView; //实时滤镜预览视图

@property (nonatomic, strong) AVCaptureStillImageOutput *photoOutput;//用于保存原图

@property (nonatomic, strong) CheckViewController *checkVC;//拍照之后跳转的ViewController

@end

@implementation CameraViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self.navigationController setNavigationBarHidden:YES];
    
    _checkVC = [[CheckViewController alloc] init];
    
    
    _cameraManager = [[MyCamera alloc] initWithSessionPreset:AVCaptureSessionPresetPhoto cameraPosition:AVCaptureDevicePositionBack];
    _cameraManager.outputImageOrientation = UIInterfaceOrientationPortrait; // 设置照片的方向为设备固定的方向
    _cameraManager.horizontallyMirrorFrontFacingCamera = YES;//设置是否为镜像
    _cameraManager.horizontallyMirrorRearFacingCamera = NO;

    _filter = [[GPUImageFilter alloc] init];//初始化滤镜，默认初始化为原图GPUImageFilter

    [self setfocusImage:[UIImage imageNamed:@"touch_focus_x"]];//初始化聚焦图片
    /**
     *设置cameraManager的输出对象为filter,然后将preview强制转换为filterView添加到filter的输出对象中，这样在filterView中显示的就是相机捕捉到的并且经过filter滤镜处理的实时图像了
     */
    [self.cameraManager addTarget:_filter];
    _filterView = (GPUImageView *)self.preview;
    [_filter addTarget:_filterView];

    //初始化闪光灯模式为Auto
    [self setFlashMode:CameraManagerFlashModeOn];
    
    //默认滤镜视图为隐藏，就是点击滤镜的按钮才会出现让你选择滤镜的那个小视图
    [self setFilterViewState:FilterViewHidden];
    
    //初始化开始及结束的缩放比例都为1.0
    [self setBeginGestureScale:1.0f];
    [self setEffectiveScale:1.0f];
    
    //启动相机捕获
    [self.cameraManager startCameraCapture];
}

- (IBAction)useFilter:(id)sender {
    
    if (self.filterViewState == FilterViewHidden) {
        [self addCameraFilterView];
        [self setFilterViewState:FilterViewUsing];
    }
    else {
        [_cameraFilterView removeFromSuperview];
        [self setFilterViewState:FilterViewHidden];
    }

    
}
- (IBAction)changeFlash:(id)sender {
    [self changeFlashMode:_flashButton];

}
- (IBAction)takePhoto:(id)sender {
    
    
//    _photoOutput = [_cameraManager getPhotoOutput];//得到源数据输出流
//    NSDictionary * outputSettings = [[NSDictionary alloc] initWithObjectsAndKeys:AVVideoCodecJPEG,AVVideoCodecKey, nil];
//    //这是输出流的设置参数AVVideoCodecJPEG参数表示以JPEG的图片格式输出图片
//    [_photoOutput setOutputSettings:outputSettings];
//    AVCaptureConnection *captureConnection=[_photoOutput connectionWithMediaType:AVMediaTypeVideo];
//    //根据连接取得设备输出的数据
//    [_photoOutput captureStillImageAsynchronouslyFromConnection:captureConnection completionHandler:^(CMSampleBufferRef imageDataSampleBuffer, NSError *error) {
//        if (imageDataSampleBuffer) {
//            NSData *imageData=[AVCaptureStillImageOutput jpegStillImageNSDataRepresentation:imageDataSampleBuffer];
//            UIImage *image=[UIImage imageWithData:imageData];
//            //将输出流数据转换成NSData，然后通过NSData将数据转换为UIImage传递给checkVC
//            _checkVC.image = image;
//            [self.navigationController pushViewController:_checkVC animated:YES];
//        }
//    }];

}

//设置闪光灯模式

- (void)setFlashMode:(CameraManagerFlashMode)flashMode {
    _flashMode = flashMode;
    
    switch (flashMode) {
        case CameraManagerFlashModeAuto: {
            [self.cameraManager.inputCamera lockForConfiguration:nil];
            if ([self.cameraManager.inputCamera flashMode]) {
                [self.cameraManager.inputCamera setFlashMode:AVCaptureFlashModeAuto];
                [self.cameraManager.inputCamera setTorchMode:AVCaptureTorchModeAuto];

            }
            [self.cameraManager.inputCamera unlockForConfiguration];
        }
            break;
        case CameraManagerFlashModeOff: {
            [self.cameraManager.inputCamera lockForConfiguration:nil];
            [self.cameraManager.inputCamera setFlashMode:AVCaptureFlashModeOff];
            [self.cameraManager.inputCamera setTorchMode:AVCaptureTorchModeOff];

            [self.cameraManager.inputCamera unlockForConfiguration];
        }
            
            break;
        case CameraManagerFlashModeOn: {
            // AVCapturePhotoSettings.flashMode
            [self.cameraManager.inputCamera lockForConfiguration:nil];
            [self.cameraManager.inputCamera setFlashMode:AVCaptureFlashModeOn];
            [self.cameraManager.inputCamera setTorchMode:AVCaptureTorchModeOn];
            [self.cameraManager.inputCamera unlockForConfiguration];
        }
            break;
            
        default:
            break;
    }
}


#pragma mark 改变闪光灯状态
- (void)changeFlashMode:(UIButton *)button {
    switch (self.flashMode) {
        case CameraManagerFlashModeAuto:
            self.flashMode = CameraManagerFlashModeOn;
            [button setImage:[UIImage imageNamed:@"flashing_on"] forState:UIControlStateNormal];
            break;
        case CameraManagerFlashModeOff:
            self.flashMode = CameraManagerFlashModeAuto;
            [button setImage:[UIImage imageNamed:@"flashing_auto"] forState:UIControlStateNormal];
            break;
        case CameraManagerFlashModeOn:
            self.flashMode = CameraManagerFlashModeOff;
            [button setImage:[UIImage imageNamed:@"flashing_off"] forState:UIControlStateNormal];
            break;
            
        default:
            break;
    }
}


//添加滤镜视图到主视图上
- (void)addCameraFilterView {
    UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
    layout.scrollDirection = UICollectionViewScrollDirectionHorizontal;
    _cameraFilterView = [[CameraFilterView alloc] initWithFrame:CGRectMake(0, HEIGHT - _bottomView.frame.size.height - (WIDTH-4)/5 - 4, WIDTH, (WIDTH-4)/5) collectionViewLayout:layout];
    NSMutableArray *filterNameArray = [[NSMutableArray alloc] initWithCapacity:CameraFilterCount];
    for (NSInteger index = 0; index < CameraFilterCount; index++) {
        UIImage *image = [UIImage imageNamed:@"girl"];
        [filterNameArray addObject:image];
    }
    _cameraFilterView.cameraFilterDelegate = self;
    _cameraFilterView.picArray = filterNameArray;
    [self.view addSubview:_cameraFilterView];
}



//设置聚焦图片
- (void)setfocusImage:(UIImage *)focusImage {
    if (!focusImage) return;
    
    if (!_focusLayer) {
        //增加tap手势，用于聚焦及曝光
        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(focus:)];
        [self.preview addGestureRecognizer:tap];
        //增加pinch手势，用于调整焦距
        UIPinchGestureRecognizer *pinch = [[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(focusDisdance:)];
        [self.preview addGestureRecognizer:pinch];
        pinch.delegate = self;
    }
    
    UIImageView *imageView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, focusImage.size.width, focusImage.size.height)];
    imageView.image = focusImage;
    CALayer *layer = imageView.layer;
    layer.hidden = YES;
    [self.preview.layer addSublayer:layer];
    _focusLayer = layer;
    
}

//调整焦距方法
-(void)focusDisdance:(UIPinchGestureRecognizer*)pinch {
    self.effectiveScale = self.beginGestureScale * pinch.scale;
    if (self.effectiveScale < 1.0f) {
        self.effectiveScale = 1.0f;
    }
    CGFloat maxScaleAndCropFactor = 3.0f;//设置最大放大倍数为3倍
    if (self.effectiveScale > maxScaleAndCropFactor)
        self.effectiveScale = maxScaleAndCropFactor;
    [CATransaction begin];
    [CATransaction setAnimationDuration:.025];
    NSError *error;
    if([self.cameraManager.inputCamera lockForConfiguration:&error]){
        [self.cameraManager.inputCamera setVideoZoomFactor:self.effectiveScale];
        [self.cameraManager.inputCamera unlockForConfiguration];
    }
    else {
        NSLog(@"ERROR = %@", error);
    }
    
    [CATransaction commit];
}

//手势代理方法
- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer
{
    if ( [gestureRecognizer isKindOfClass:[UIPinchGestureRecognizer class]] ) {
        self.beginGestureScale = self.effectiveScale;
    }
    return YES;
}

//对焦方法
- (void)focus:(UITapGestureRecognizer *)tap {
    self.preview.userInteractionEnabled = NO;
    CGPoint touchPoint = [tap locationInView:tap.view];
    // CGContextRef *touchContext = UIGraphicsGetCurrentContext();
    [self layerAnimationWithPoint:touchPoint];
    /**
     *下面是照相机焦点坐标轴和屏幕坐标轴的映射问题，这个坑困惑了我好久，花了各种方案来解决这个问题，以下是最简单的解决方案也是最准确的坐标转换方式
     */
    if(_cameraManager.cameraPosition == AVCaptureDevicePositionBack){
        touchPoint = CGPointMake( touchPoint.y /tap.view.bounds.size.height ,1-touchPoint.x/tap.view.bounds.size.width);
    }
    else
        touchPoint = CGPointMake(touchPoint.y /tap.view.bounds.size.height ,touchPoint.x/tap.view.bounds.size.width);
    /*以下是相机的聚焦和曝光设置，前置不支持聚焦但是可以曝光处理，后置相机两者都支持，下面的方法是通过点击一个点同时设置聚焦和曝光，当然根据需要也可以分开进行处理
     */
    if([self.cameraManager.inputCamera isExposurePointOfInterestSupported] && [self.cameraManager.inputCamera isExposureModeSupported:AVCaptureExposureModeContinuousAutoExposure])
    {
        NSError *error;
        if ([self.cameraManager.inputCamera lockForConfiguration:&error]) {
            [self.cameraManager.inputCamera setExposurePointOfInterest:touchPoint];
            [self.cameraManager.inputCamera setExposureMode:AVCaptureExposureModeContinuousAutoExposure];
            if ([self.cameraManager.inputCamera isFocusPointOfInterestSupported] && [self.cameraManager.inputCamera isFocusModeSupported:AVCaptureFocusModeAutoFocus]) {
                [self.cameraManager.inputCamera setFocusPointOfInterest:touchPoint];
                [self.cameraManager.inputCamera setFocusMode:AVCaptureFocusModeAutoFocus];
            }
            [self.cameraManager.inputCamera unlockForConfiguration];
        } else {
            NSLog(@"ERROR = %@", error);
        }
    }
}

//对焦动画
- (void)layerAnimationWithPoint:(CGPoint)point {
    if (_focusLayer) {
        ///聚焦点聚焦动画设置
        CALayer *focusLayer = _focusLayer;
        focusLayer.hidden = NO;
        [CATransaction begin];
        [CATransaction setDisableActions:YES];
        [focusLayer setPosition:point];
        focusLayer.transform = CATransform3DMakeScale(2.0f,2.0f,1.0f);
        [CATransaction commit];
        
        CABasicAnimation *animation = [ CABasicAnimation animationWithKeyPath: @"transform" ];
        animation.toValue = [ NSValue valueWithCATransform3D: CATransform3DMakeScale(1.0f,1.0f,1.0f)];
        animation.delegate = self;
        animation.duration = 0.3f;
        animation.repeatCount = 1;
        animation.removedOnCompletion = NO;
        animation.fillMode = kCAFillModeForwards;
        [focusLayer addAnimation: animation forKey:@"animation"];
    }
}

//动画的delegate方法
- (void)animationDidStop:(CAAnimation *)anim finished:(BOOL)flag {
    //    1秒钟延时
    [self performSelector:@selector(focusLayerNormal) withObject:self afterDelay:0.5f];
}

//focusLayer回到初始化状态
- (void)focusLayerNormal {
    self.preview.userInteractionEnabled = YES;
    _focusLayer.hidden = YES;
}



/**
 *以下的滤镜是GPUImage自带的滤镜，后面有几个效果不是很明显，我只是拿来做测试用。
 *GPUImage自带的滤镜很多，大家可以都试试看，当然也可以自己写滤镜，这就需要后续深入学习了
 *对checkViewController中filtercode属性的说明：filtercode是在选择滤镜的时候设置，
 *在拍照的时候传值给CheckViewController，实际上拍照传递给CheckVC的是原图加上当前设置的filtercode，
 *所以在后续CheckVC中改变滤镜的时候是基于原图进行改变。
 */
- (void)switchCameraFilter:(NSInteger)index {
    [self.cameraManager removeAllTargets];
    switch (index) {
        case 0:
            _filter = [[GPUImageFilter alloc] init];//原图
            [_checkVC setFilterCode:0];
            break;
        case 1:
            _filter = [[GPUImageHueFilter alloc] init];//绿巨人
            [_checkVC setFilterCode:1];
            break;
        case 2:
            _filter = [[GPUImageColorInvertFilter alloc] init];//负片
            [_checkVC setFilterCode:2];
            break;
        case 3:
            _filter = [[GPUImageSepiaFilter alloc] init];//老照片
            [_checkVC setFilterCode:3];
            break;
        case 4: {
            _filter = [[GPUImageGaussianBlurPositionFilter alloc] init];
            [(GPUImageGaussianBlurPositionFilter*)_filter setBlurRadius:40.0/320.0];
            [_checkVC setFilterCode:4];
        }
            break;
        case 5:
            _filter = [[GPUImageSketchFilter alloc] init];//素描
            [_checkVC setFilterCode:5];
            break;
        case 6:
            _filter = [[GPUImageVignetteFilter alloc] init];//黑晕
            [_checkVC setFilterCode:6];
            break;
        case 7:
            _filter = [[GPUImageGrayscaleFilter alloc] init];//灰度
            [_checkVC setFilterCode:7];
            break;
        case 8:
            _filter = [[GPUImageToonFilter alloc] init];//卡通效果 黑色粗线描边
            [_checkVC setFilterCode:8];
        default:
            _filter = [[GPUImageFilter alloc] init];
            [_checkVC setFilterCode:9];
            break;
    }
    
    [self.cameraManager addTarget:_filter];
    [_filter addTarget:_filterView];
}


@end
