//
//  ViewController.m
//  NewOpenGLES
//
//  Created by 黎仕仪 on 18/2/5.
//  Copyright © 2018年 shiyi.Li. All rights reserved.
//

#import "ViewController.h"
#import "NewOpenGLView.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    NewOpenGLView *newView = [[NewOpenGLView alloc]initWithFrame:self.view.bounds];
    [self.view addSubview:newView];
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
