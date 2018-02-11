//
//  ViewController.m
//  ARExample
//
//  Created by ZhangXiaoJun on 2017/7/5.
//  Copyright © 2017年 ZhangXiaoJun. All rights reserved.
//

#import "NodeViewController.h"
#import <ARKit/ARKit.h>
#import "NodeRenderer.h"

@interface NodeViewController ()
@property (nonatomic, strong) id<GLKViewDelegate> renderer;
@property (weak, nonatomic) IBOutlet GLKView *glView;
@property (nonatomic, strong) CADisplayLink *displayLink;
@end

@implementation NodeViewController

- (void)viewDidLoad {
    [super viewDidLoad];
}

- (void)viewWillAppear:(BOOL)animated
{
    printf("node view will appear\n");
  
    [super viewWillAppear:animated];
    
    self.displayLink = [CADisplayLink displayLinkWithTarget:self.glView selector:@selector(display)];
    [self.displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSDefaultRunLoopMode];
    
    self.renderer = [NodeRenderer alloc];
    self.glView.context = ((NodeRenderer *)self.renderer).context;
    self.glView.drawableDepthFormat = GLKViewDrawableDepthFormatNone;
    self.glView.drawableStencilFormat = GLKViewDrawableStencilFormatNone;
    self.glView.drawableMultisample = GLKViewDrawableMultisampleNone;
    self.glView.delegate = self.renderer;
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [self.displayLink invalidate];
    self.displayLink = nil;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
