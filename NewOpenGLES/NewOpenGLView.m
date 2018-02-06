//
//  NewOpenGLView.m
//  NewOpenGLES
//
//  Created by 黎仕仪 on 18/2/5.
//  Copyright © 2018年 shiyi.Li. All rights reserved.
//

#import "NewOpenGLView.h"
#import "GLESUtils.h"
#import <OpenGLES/ES3/gl.h>
#import <GLKit/GLKit.h>
#import "TextureManager.h"

@interface NewOpenGLView ()
{
    CAEAGLLayer *_eaglLayer;
    EAGLContext *_context;
    GLuint _depthBuffer;
    GLuint _colorBuffer;
    GLuint _frameBuffer;
    
    GLuint _programHandle; //着色器程序
    GLuint _positionSlot; //顶点槽位
    GLuint _colorSlot;   //颜色槽位
    GLuint _projectionSlot;  //投影矩阵槽位
    GLuint _modelViewSlot;   //模型矩阵槽位
    GLKMatrix4 _projectionMatrix; //投影矩阵
    GLKMatrix4 _modelViewMatrix;  //模型(其实是观察)矩阵
    
    //纹理
    GLuint _textureProgram;
    GLuint _texPositionSlot; //顶点槽位
    GLuint _texCoordSlot;   //纹理坐标槽位
    GLuint _ourTextureSlot; //纹理采样对象槽位
    GLuint _texProjectionSlot;  //投影矩阵槽位
    GLuint _texModelViewSlot;   //模型矩阵槽位
    GLKMatrix4 _texProjectionMatrix; //投影矩阵
    GLKMatrix4 _texModelViewMatrix;  //模型(其实是观察)矩阵
    
    //3个纹理对象
    GLuint _textureID1;  //纹理对象
    GLuint _textureID2;  //纹理对象
    GLuint _textureID3;  //纹理对象

}

@end

@implementation NewOpenGLView

-(instancetype)initWithFrame:(CGRect)frame{
    if (self==[super initWithFrame:frame]) {
        
        [self setupLayerAndContext];
        [self setupBuffers];
        [self setupProgram];
        [self render];
        
    }
    return self;
}

+(Class)layerClass{
    //OpenGL内容只会在此类layer上描绘
    return [CAEAGLLayer class];
}

- (void)setupLayerAndContext
{
    _eaglLayer = (CAEAGLLayer*) self.layer;
    
    // CALayer 默认是透明的，必须将它设为不透明才能让其可见,性能最好
    _eaglLayer.opaque = YES;
    
    // 设置描绘属性，在这里设置不维持渲染内容以及颜色格式为 RGBA8
    _eaglLayer.drawableProperties = [NSDictionary dictionaryWithObjectsAndKeys:
                                     [NSNumber numberWithBool:NO], kEAGLDrawablePropertyRetainedBacking, kEAGLColorFormatRGBA8, kEAGLDrawablePropertyColorFormat, nil];
    
    // 指定 OpenGLES 渲染API的版本，在这里我们使用OpenGLES 3.0，由于3.0兼容2.0并且功能更强，为何不用更好的呢,不过注意：3.0支持的手机最低为5s，系统最低为iOS7
    EAGLRenderingAPI api = kEAGLRenderingAPIOpenGLES3;
    _context = [[EAGLContext alloc] initWithAPI:api];
    if (!_context) {
        NSLog(@"Failed to initialize OpenGLES 3.0 context");
    }
    
    // 设置为当前上下文
    [EAGLContext setCurrentContext:_context];
}

-(void)setupBuffers{
//    1.depth
    glGenRenderbuffers(1, &_depthBuffer);
    glBindRenderbuffer(GL_RENDERBUFFER, _depthBuffer);
    glRenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH_COMPONENT16, self.frame.size.width, self.frame.size.height);
    
//    2.color
    glGenRenderbuffers(1, &_colorBuffer); //生成和绑定render buffer的API函数
    glBindRenderbuffer(GL_RENDERBUFFER, _colorBuffer);
    //为其分配空间
    [_context renderbufferStorage:GL_RENDERBUFFER fromDrawable:_eaglLayer];
    
//    3.frame
    glGenFramebuffers(1, &_frameBuffer);   //生成和绑定frame buffer的API函数
    glBindFramebuffer(GL_FRAMEBUFFER, _frameBuffer);
    //将renderbuffer跟framebuffer进行绑定
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, _colorBuffer);
    //将depthBuffer跟framebuffer进行绑定
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, GL_RENDERBUFFER, _depthBuffer);

}

-(void)setupProgram{
    //1.多边体program
    NSString *vertexShaderPath   = [[NSBundle mainBundle] pathForResource:@"VertexShader"
                                          ofType:@"glsl"];
    NSString *fragmentShaderPath = [[NSBundle mainBundle] pathForResource:@"FragmentShader"
                                                                    ofType:@"glsl"];
    _programHandle = [GLESUtils loadProgram:vertexShaderPath withFragmentShaderFilepath:fragmentShaderPath];
    
    //获取槽位
    _positionSlot   = glGetAttribLocation(_programHandle, "vPosition");
    _colorSlot      = glGetAttribLocation(_programHandle, "vSourceColor");
    _projectionSlot = glGetUniformLocation(_programHandle, "projection");
    _modelViewSlot  = glGetUniformLocation(_programHandle, "modelView");
    
    glEnableVertexAttribArray(_positionSlot);
    glEnableVertexAttribArray(_colorSlot);
    
    
//    ------------------------------------------------------------------------
    
    //2.纹理program
    NSString *texVertexPath   = [[NSBundle mainBundle] pathForResource:@"TextureVertex"
                                                                 ofType:@"glsl"];
    NSString *texFragmentPath = [[NSBundle mainBundle] pathForResource:@"TextureFragment"
                                                                   ofType:@"glsl"];
    _textureProgram = [GLESUtils loadProgram:texVertexPath withFragmentShaderFilepath:texFragmentPath];
    
    //获取槽位
    _texPositionSlot = glGetAttribLocation(_textureProgram, "Position");
    _texCoordSlot    = glGetAttribLocation(_textureProgram, "TexCoordIn");
    glEnableVertexAttribArray(_texPositionSlot);
    glEnableVertexAttribArray(_texCoordSlot);
    
    _ourTextureSlot    = glGetUniformLocation(_textureProgram, "ourTexture");
    _texProjectionSlot = glGetUniformLocation(_textureProgram, "Projection");
    _texModelViewSlot  = glGetUniformLocation(_textureProgram, "ModelView");
    
    //获取纹理对象
    _textureID1 = [TextureManager getTextureImage:[UIImage imageNamed:@"猫头鹰"]];
    _textureID2 = [TextureManager getTextureImage:[UIImage imageNamed:@"乌龟"]];
    _textureID3 = [TextureManager getTextureImage:[UIImage imageNamed:@"变色龙"]];

}

-(void)setupProjectionMatrixAndModelViewMatrix{
    //1.多边体
    float aspect = self.frame.size.width/self.frame.size.height;
    _projectionMatrix = GLKMatrix4MakePerspective(45.0*M_PI/180.0, aspect, 0.1, 100);
    glUniformMatrix4fv(_projectionSlot, 1, GL_FALSE, _projectionMatrix.m);
    
    _modelViewMatrix = GLKMatrix4MakeTranslation(0, 0, -5); //平移
    _modelViewMatrix = GLKMatrix4RotateX(_modelViewMatrix, 0.6);  //旋转X轴
    glUniformMatrix4fv(_modelViewSlot, 1, GL_FALSE, _modelViewMatrix.m);
}

-(void)setupTextureProjectionMatrixAndModelViewMatrix{
    //2.纹理
    float aspect = self.frame.size.width/self.frame.size.height;
    _texProjectionMatrix = GLKMatrix4MakePerspective(45.0*M_PI/180.0, aspect, 0.1, 100);
    glUniformMatrix4fv(_texProjectionSlot, 1, GL_FALSE, _texProjectionMatrix.m);
    
    _texModelViewMatrix = GLKMatrix4MakeTranslation(0, 0, -5); //平移
    _texModelViewMatrix = GLKMatrix4RotateX(_texModelViewMatrix, 1.4);  //旋转X轴
    glUniformMatrix4fv(_texModelViewSlot, 1, GL_FALSE, _texModelViewMatrix.m);
}

-(void)render
{
    
    //设置清屏颜色,默认是黑色，如果你的运行结果是黑色，问题就可能在这儿
    glClearColor(0.3, 0.5, 0.8, 1.0);
    /*
     glClear指定清除的buffer
     共可设置三个选项GL_COLOR_BUFFER_BIT，GL_DEPTH_BUFFER_BIT和GL_STENCIL_BUFFER_BIT
     也可组合如:glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
     */
    
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    // Setup viewport
    glViewport(0, 0, self.frame.size.width, self.frame.size.height);
    
    //开启深度测试
    glEnable(GL_DEPTH_TEST);
    //绘制3个多边体
    glUseProgram(_programHandle);
    [self setupProjectionMatrixAndModelViewMatrix];
    [self drawFirstCube];
    [self drawSecondCube];
    [self drawThirdCube];
    
    //绘制纹理
    glUseProgram(_textureProgram);
    [self setupTextureProjectionMatrixAndModelViewMatrix];
    [self drawTextrue];
    
    [_context presentRenderbuffer:_colorBuffer];
}

-(void)drawFirstCube{
    //顶点数据
    GLfloat ver[] = {
        -0.508680,0.260000,-0.725382,0.345678,0.678943,0.812332,0.900000,
        0.306216,0.260000,-0.725382,0.345678,0.678943,0.812332,0.900000,
        0.306216,0.260000,-0.244226,0.345678,0.678943,0.812332,0.900000,
        -0.508680,0.260000,-0.244226,0.345678,0.678943,0.812332,0.900000,
        -0.508680,0.010000,-0.725382,0.345678,0.678943,0.812332,0.900000,
        0.306216,0.010000,-0.725382,0.345678,0.678943,0.812332,0.900000,
        0.306216,0.010000,-0.244226,0.345678,0.678943,0.812332,0.900000,
        -0.508680,0.010000,-0.244226,0.345678,0.678943,0.812332,0.900000,
    };
    
    //顶面和底面索引
    GLubyte ind_top[] = {
        3,0,1,1,2,3,
    };
    
    GLubyte ind_bot[] = {
        3+4,0+4,1+4,1+4,2+4,3+4,
    };
    
    //侧面索引
    GLubyte side[] = {
        0,4,1,5,2,6,3,7,0,4,
    };
    
    //    绘制
    //    顶面
    glVertexAttribPointer(_positionSlot, 3, GL_FLOAT, GL_FALSE, 7 * sizeof(float), ver);
    glVertexAttribPointer(_colorSlot, 4, GL_FLOAT, GL_FALSE, 7 * sizeof(float), ver+3);
    glDrawElements(GL_TRIANGLES, sizeof(ind_top)/sizeof(GLubyte), GL_UNSIGNED_BYTE, ind_top);
    
    //    底面
    glVertexAttribPointer(_positionSlot, 3, GL_FLOAT, GL_FALSE, 7 * sizeof(float), ver);
    glVertexAttribPointer(_colorSlot, 4, GL_FLOAT, GL_FALSE, 7 * sizeof(float), ver+3);
    glDrawElements(GL_TRIANGLES, sizeof(ind_bot)/sizeof(GLubyte), GL_UNSIGNED_BYTE, ind_bot);
    
    //    侧面
    glVertexAttribPointer(_positionSlot, 3, GL_FLOAT, GL_FALSE, 7 * sizeof(float), ver);
    glVertexAttribPointer(_colorSlot, 4, GL_FLOAT, GL_FALSE, 7 * sizeof(float), ver+3);
    glDrawElements(GL_TRIANGLE_STRIP, sizeof(side)/sizeof(GLubyte), GL_UNSIGNED_BYTE, side);
    
    //需要画的线  顶面和底面线
    GLfloat line[] = {
        -0.508680,0.260000,-0.725382,0.965789,0.677845,0.812332,1.0,
        0.306216,0.260000,-0.725382,0.965789,0.677845,0.812332,1.0,
        0.306216,0.260000,-0.244226,0.965789,0.677845,0.812332,1.0,
        -0.508680,0.260000,-0.244226,0.965789,0.677845,0.812332,1.0,
        -0.508680,0.010000,-0.725382,0.965789,0.677845,0.812332,1.0,
        0.306216,0.010000,-0.725382,0.965789,0.677845,0.812332,1.0,
        0.306216,0.010000,-0.244226,0.965789,0.677845,0.812332,1.0,
        -0.508680,0.010000,-0.244226,0.965789,0.677845,0.812332,1.0,
    };
    
    GLubyte line_top[] = {
        0,1,2,3,
    };
    
    GLubyte line_bot[] = {
        0+4,1+4,2+4,3+4,
    };
    
    glVertexAttribPointer(_positionSlot, 3, GL_FLOAT, GL_FALSE, 7 * sizeof(float), line);
    glVertexAttribPointer(_colorSlot, 4, GL_FLOAT, GL_FALSE, 7 * sizeof(float), line+3);
    glDrawElements(GL_LINE_LOOP, sizeof(line_top)/sizeof(GLubyte), GL_UNSIGNED_BYTE, line_top);
    
    glVertexAttribPointer(_positionSlot, 3, GL_FLOAT, GL_FALSE, 7 * sizeof(float), line);
    glVertexAttribPointer(_colorSlot, 4, GL_FLOAT, GL_FALSE, 7 * sizeof(float), line+3);
    glDrawElements(GL_LINE_LOOP, sizeof(line_bot)/sizeof(GLubyte), GL_UNSIGNED_BYTE, line_bot);

}

-(void)drawSecondCube{

    //顶点数据
    GLfloat ver[] = {
        -0.304217,0.260000,0.814439,0.345678,0.678943,0.465789,0.900000,
        -0.304217,0.260000,0.344297,0.345678,0.678943,0.465789,0.900000,
        0.429602,0.260000,0.344297,0.345678,0.678943,0.465789,0.900000,
        0.426395,0.260000,0.718223,0.345678,0.678943,0.465789,0.900000,
        0.169820,0.260000,0.718223,0.345678,0.678943,0.465789,0.900000,
        0.169820,0.260000,0.814439,0.345678,0.678943,0.465789,0.900000,
        -0.304217,0.010000,0.814439,0.345678,0.678943,0.465789,0.900000,
        -0.304217,0.010000,0.344297,0.345678,0.678943,0.465789,0.900000,
        0.429602,0.010000,0.344297,0.345678,0.678943,0.465789,0.900000,
        0.426395,0.010000,0.718223,0.345678,0.678943,0.465789,0.900000,
        0.169820,0.010000,0.718223,0.345678,0.678943,0.465789,0.900000,
        0.169820,0.010000,0.814439,0.345678,0.678943,0.465789,0.900000,
    };
    
    //顶面和底面索引
    GLubyte ind_top[] = {
        5,0,1,1,2,3,4,5,1,1,3,4,
    };
    
    GLubyte ind_bot[] = {
        5+6,0+6,1+6,1+6,2+6,3+6,4+6,5+6,1+6,1+6,3+6,4+6,
    };
    
    //侧面索引
    GLubyte side[] = {
        0,6,1,7,2,8,3,9,4,10,5,11,0,6,
    };
    
    //    绘制
    //    顶面
    glVertexAttribPointer(_positionSlot, 3, GL_FLOAT, GL_FALSE, 7 * sizeof(float), ver);
    glVertexAttribPointer(_colorSlot, 4, GL_FLOAT, GL_FALSE, 7 * sizeof(float), ver+3);
    glDrawElements(GL_TRIANGLES, sizeof(ind_top)/sizeof(GLubyte), GL_UNSIGNED_BYTE, ind_top);
    
    //    底面
    glVertexAttribPointer(_positionSlot, 3, GL_FLOAT, GL_FALSE, 7 * sizeof(float), ver);
    glVertexAttribPointer(_colorSlot, 4, GL_FLOAT, GL_FALSE, 7 * sizeof(float), ver+3);
    glDrawElements(GL_TRIANGLES, sizeof(ind_bot)/sizeof(GLubyte), GL_UNSIGNED_BYTE, ind_bot);
    
    //    侧面
    glVertexAttribPointer(_positionSlot, 3, GL_FLOAT, GL_FALSE, 7 * sizeof(float), ver);
    glVertexAttribPointer(_colorSlot, 4, GL_FLOAT, GL_FALSE, 7 * sizeof(float), ver+3);
    glDrawElements(GL_TRIANGLE_STRIP, sizeof(side)/sizeof(GLubyte), GL_UNSIGNED_BYTE, side);
    
    //需要画的线
    GLfloat line[] = {
        -0.304217,0.260000,0.814439,0.965789,0.678943,0.465789,1.000000,
        -0.304217,0.260000,0.344297,0.965789,0.678943,0.465789,1.000000,
        0.429602,0.260000,0.344297,0.965789,0.678943,0.465789,1.000000,
        0.426395,0.260000,0.718223,0.965789,0.678943,0.465789,1.000000,
        0.169820,0.260000,0.718223,0.965789,0.678943,0.465789,1.000000,
        0.169820,0.260000,0.814439,0.965789,0.678943,0.465789,1.000000,
        -0.304217,0.010000,0.814439,0.965789,0.678943,0.465789,1.000000,
        -0.304217,0.010000,0.344297,0.965789,0.678943,0.465789,1.000000,
        0.429602,0.010000,0.344297,0.965789,0.678943,0.465789,1.000000,
        0.426395,0.010000,0.718223,0.965789,0.678943,0.465789,1.000000,
        0.169820,0.010000,0.718223,0.965789,0.678943,0.465789,1.000000,
        0.169820,0.010000,0.814439,0.965789,0.678943,0.465789,1.000000,
    };
    
    GLubyte line_top[] = {
        0,1,2,3,4,5,
    };
    
    GLubyte line_bot[] = {
        0+6,1+6,2+6,3+6,4+6,5+6,
    };
    
    glVertexAttribPointer(_positionSlot, 3, GL_FLOAT, GL_FALSE, 7 * sizeof(float), line);
    glVertexAttribPointer(_colorSlot, 4, GL_FLOAT, GL_FALSE, 7 * sizeof(float), line+3);
    glDrawElements(GL_LINE_LOOP, sizeof(line_top)/sizeof(GLubyte), GL_UNSIGNED_BYTE, line_top);
    
    glVertexAttribPointer(_positionSlot, 3, GL_FLOAT, GL_FALSE, 7 * sizeof(float), line);
    glVertexAttribPointer(_colorSlot, 4, GL_FLOAT, GL_FALSE, 7 * sizeof(float), line+3);
    glDrawElements(GL_LINE_LOOP, sizeof(line_bot)/sizeof(GLubyte), GL_UNSIGNED_BYTE, line_bot);

}

-(void)drawThirdCube{
    //顶点数据
    GLfloat ver[] = {
        0.306216,0.260000,-0.725382,0.778943,0.378943,0.465789,0.900000,
        0.429602,0.260000,-0.725382,0.778943,0.378943,0.465789,0.900000,
        0.602136,0.260000,-0.725382,0.778943,0.378943,0.465789,0.900000,
        0.602136,0.260000,-0.816786,0.778943,0.378943,0.465789,0.900000,
        0.987652,0.260000,-0.816786,0.778943,0.378943,0.465789,0.900000,
        0.987652,0.260000,-0.430321,0.778943,0.378943,0.465789,0.900000,
        0.901058,0.260000,-0.430321,0.778943,0.378943,0.465789,0.900000,
        0.901058,0.260000,-0.319931,0.778943,0.378943,0.465789,0.900000,
        0.622946,0.260000,-0.319931,0.778943,0.378943,0.465789,0.900000,
        0.306216,0.260000,-0.319931,0.778943,0.378943,0.465789,0.900000,
        0.306216,0.010000,-0.725382,0.778943,0.378943,0.465789,0.900000,
        0.429602,0.010000,-0.725382,0.778943,0.378943,0.465789,0.900000,
        0.602136,0.010000,-0.725382,0.778943,0.378943,0.465789,0.900000,
        0.602136,0.010000,-0.816786,0.778943,0.378943,0.465789,0.900000,
        0.987652,0.010000,-0.816786,0.778943,0.378943,0.465789,0.900000,
        0.987652,0.010000,-0.430321,0.778943,0.378943,0.465789,0.900000,
        0.901058,0.010000,-0.430321,0.778943,0.378943,0.465789,0.900000,
        0.901058,0.010000,-0.319931,0.778943,0.378943,0.465789,0.900000,
        0.622946,0.010000,-0.319931,0.778943,0.378943,0.465789,0.900000,
        0.306216,0.010000,-0.319931,0.778943,0.378943,0.465789,0.900000,
    };
    
    //顶面和底面索引
    GLubyte ind_top[] = {
        9,0,1,2,3,4,4,5,6,6,7,8,8,9,1,2,4,6,6,8,1,1,2,6,
    };
    
    GLubyte ind_bot[] = {
        9+10,0+10,1+10,2+10,3+10,4+10,4+10,5+10,6+10,6+10,7+10,8+10,8+10,9+10,1+10,2+10,4+10,6+10,6+10,8+10,1+10,1+10,2+10,6+10,
    };
    
    //侧面索引
    GLubyte side[] = {
        0,10,1,11,2,12,3,13,4,14,5,15,6,16,7,17,8,18,9,19,0,10,
    };
    
    //    绘制
    //    顶面
    glVertexAttribPointer(_positionSlot, 3, GL_FLOAT, GL_FALSE, 7 * sizeof(float), ver);
    glVertexAttribPointer(_colorSlot, 4, GL_FLOAT, GL_FALSE, 7 * sizeof(float), ver+3);
    glDrawElements(GL_TRIANGLES, sizeof(ind_top)/sizeof(GLubyte), GL_UNSIGNED_BYTE, ind_top);
    
    //    底面
    glVertexAttribPointer(_positionSlot, 3, GL_FLOAT, GL_FALSE, 7 * sizeof(float), ver);
    glVertexAttribPointer(_colorSlot, 4, GL_FLOAT, GL_FALSE, 7 * sizeof(float), ver+3);
    glDrawElements(GL_TRIANGLES, sizeof(ind_bot)/sizeof(GLubyte), GL_UNSIGNED_BYTE, ind_bot);
    
    //    侧面
    glVertexAttribPointer(_positionSlot, 3, GL_FLOAT, GL_FALSE, 7 * sizeof(float), ver);
    glVertexAttribPointer(_colorSlot, 4, GL_FLOAT, GL_FALSE, 7 * sizeof(float), ver+3);
    glDrawElements(GL_TRIANGLE_STRIP, sizeof(side)/sizeof(GLubyte), GL_UNSIGNED_BYTE, side);
    
    //需要画的线
    GLfloat line[] = {
        0.306216,0.260000,-0.725382,0.345678,0.678943,0.465789,1.000000,
        0.429602,0.260000,-0.725382,0.345678,0.678943,0.465789,1.000000,
        0.602136,0.260000,-0.725382,0.345678,0.678943,0.465789,1.000000,
        0.602136,0.260000,-0.816786,0.345678,0.678943,0.465789,1.000000,
        0.987652,0.260000,-0.816786,0.345678,0.678943,0.465789,1.000000,
        0.987652,0.260000,-0.430321,0.345678,0.678943,0.465789,1.000000,
        0.901058,0.260000,-0.430321,0.345678,0.678943,0.465789,1.000000,
        0.901058,0.260000,-0.319931,0.345678,0.678943,0.465789,1.000000,
        0.622946,0.260000,-0.319931,0.345678,0.678943,0.465789,1.000000,
        0.306216,0.260000,-0.319931,0.345678,0.678943,0.465789,1.000000,
        0.306216,0.010000,-0.725382,0.345678,0.678943,0.465789,1.000000,
        0.429602,0.010000,-0.725382,0.345678,0.678943,0.465789,1.000000,
        0.602136,0.010000,-0.725382,0.345678,0.678943,0.465789,1.000000,
        0.602136,0.010000,-0.816786,0.345678,0.678943,0.465789,1.000000,
        0.987652,0.010000,-0.816786,0.345678,0.678943,0.465789,1.000000,
        0.987652,0.010000,-0.430321,0.345678,0.678943,0.465789,1.000000,
        0.901058,0.010000,-0.430321,0.345678,0.678943,0.465789,1.000000,
        0.901058,0.010000,-0.319931,0.345678,0.678943,0.465789,1.000000,
        0.622946,0.010000,-0.319931,0.345678,0.678943,0.465789,1.000000,
        0.306216,0.010000,-0.319931,0.345678,0.678943,0.465789,1.000000,
    };
    
    GLubyte line_top[] = {
        0,1,2,3,4,5,6,7,8,9,
    };
    
    GLubyte line_bot[] = {
        0+10,1+10,2+10,3+10,4+10,5+10,6+10,7+10,8+10,9+10,
    };
    
    glVertexAttribPointer(_positionSlot, 3, GL_FLOAT, GL_FALSE, 7 * sizeof(float), line);
    glVertexAttribPointer(_colorSlot, 4, GL_FLOAT, GL_FALSE, 7 * sizeof(float), line+3);
    glDrawElements(GL_LINE_LOOP, sizeof(line_top)/sizeof(GLubyte), GL_UNSIGNED_BYTE, line_top);
    
    glVertexAttribPointer(_positionSlot, 3, GL_FLOAT, GL_FALSE, 7 * sizeof(float), line);
    glVertexAttribPointer(_colorSlot, 4, GL_FLOAT, GL_FALSE, 7 * sizeof(float), line+3);
    glDrawElements(GL_LINE_LOOP, sizeof(line_bot)/sizeof(GLubyte), GL_UNSIGNED_BYTE, line_bot);

}

//绘制纹理
-(void)drawTextrue{
//    构造3个纹理的顶点坐标
    //四个顶点(分别表示xyz轴)

//    第一个
    GLfloat vertices1[] = {
        //   x    y    z
        -0.9,  0.3, -0.9,  //左下
        -0.6,  0.3, -0.9,  //右下
        -0.9,  0.3, -0.6,  //左上
        -0.6,  0.3, -0.6,  //右上
    };
    
    //    第二个
    GLfloat vertices2[] = {
        //   x    y    z
        -0.5,  0.3, -0.5,  //左下
        -0.2,  0.3, -0.5,  //右下
        -0.5,  0.3, -0.2,  //左上
        -0.2,  0.3, -0.2,  //右上
    };
    
    //    第三个
    GLfloat vertices3[] = {
    //   x    y    z
        -0.9,  0.3, -0.1,  //左下
        -0.6,  0.3, -0.1,  //右下
        -0.9,  0.3, 0.2,  //左上
        -0.6,  0.3, 0.2,  //右上
    };
    
    //纹理4个顶点对应纹理坐标，三个都是一样的
    GLfloat textureCoord[] = {
        0, 0,
        1, 0,
        0, 1,
        1, 1,
    };

    //绘制
    glVertexAttribPointer(_texPositionSlot, 3, GL_FLOAT, GL_FALSE, 0, vertices1);
    glVertexAttribPointer(_texCoordSlot, 2, GL_FLOAT, GL_FALSE, 0, textureCoord);
    //使用纹理单元
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, _textureID1);
    glUniform1i(_ourTextureSlot, 0);
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
    
    glVertexAttribPointer(_texPositionSlot, 3, GL_FLOAT, GL_FALSE, 0, vertices2);
    glVertexAttribPointer(_texCoordSlot, 2, GL_FLOAT, GL_FALSE, 0, textureCoord);
    //使用纹理单元
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, _textureID2);
    glUniform1i(_ourTextureSlot, 0);
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
    
    glVertexAttribPointer(_texPositionSlot, 3, GL_FLOAT, GL_FALSE, 0, vertices3);
    glVertexAttribPointer(_texCoordSlot, 2, GL_FLOAT, GL_FALSE, 0, textureCoord);
    //使用纹理单元
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, _textureID3);
    glUniform1i(_ourTextureSlot, 0);
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
    
}



@end
