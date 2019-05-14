//
//  KeyboardViewController.m
//  Keyboard
//
//  Created by everettjf on 2019/5/14.
//  Copyright © 2019 everettjf. All rights reserved.
//

#import "KeyboardViewController.h"
#import "Masonry.h"
#import "TinyKeyboardView.h"
#include <pthread.h>
#import "ForEachWithRandomDelay.h"

@interface KeyboardViewController () <TinyKeyboardViewDelegate>
@property (nonatomic, strong) UIView *contentView;
@property (nonatomic, strong) UIView *buttonView;

@property (nonatomic, strong) TinyKeyboardView *tinyView;

@property (nonatomic, strong) UIButton *nextKeyboardButton;
@property (nonatomic, strong) UIButton *tinyKeyboardButton;
@property (nonatomic, strong) UIButton *deleteButton;
@property (nonatomic, strong) UIButton *returnButton;

@property (nonatomic, strong) UILabel *textLabel;
@property (nonatomic, strong) UIButton *inputButton;

@property (nonatomic, strong) NSString *pasteboardString;
@property (nonatomic, strong) ForEachWithRandomDelay *delayAction;

@property (strong, nonatomic) NSTimer *pasteboardCheckTimer;
@property (assign, nonatomic) NSInteger pasteboardChangeCount;

@end

@implementation KeyboardViewController

- (void)updateViewConstraints {
    [super updateViewConstraints];
    
    // Add custom view sizing constraints here
}

- (BOOL)fullAccessAvailable{
    static BOOL hasfullAccess = YES;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        if(@available(iOS 11.0,*)){
            hasfullAccess = [self hasFullAccess];
        }else{
            if([UIPasteboard generalPasteboard]){
                hasfullAccess = YES;
            }else{
                hasfullAccess = NO;
            }
        }
    });
    return hasfullAccess;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self setupUI];
    
    if ([self fullAccessAvailable]) {
        
        [self showStatusText:@"..."];
    } else {
        [self showFullAccessGuide];
    }
}

- (void)showFullAccessGuide{
    for(UIView * view in self.contentView.subviews){
        view.hidden = YES;
    }
    UITextView *textView = [[UITextView alloc] init];
    textView.backgroundColor = [UIColor clearColor];
    textView.editable = NO;
    textView.selectable = NO;
    textView.font = [UIFont systemFontOfSize:16];
    [self.contentView addSubview:textView];
    [textView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.mas_equalTo(self.contentView);
    }];
    textView.text = @"Please go to Settings > General > Keyboard > Keyboards > Paste Keyboard, and make sure Allow Full Access is turned on.";
    
    [self.contentView mas_updateConstraints:^(MASConstraintMaker *make) {
        make.height.mas_greaterThanOrEqualTo(120);
    }];
}

- (void)refreshDataFromPasteboard{
    
    self.pasteboardString = [UIPasteboard generalPasteboard].string;
    NSLog(@"text in pasteboard = %@",self.pasteboardString);
    
    NSString *text = [self.pasteboardString copy];
    if(text.length > 30){
        text = [text substringToIndex:30];
        text = [text stringByAppendingString:@" ..."];
    }
    [self showStatusText:text];
}

- (void)initPasteboardData {
    if(![self fullAccessAvailable]){
        return;
    }
    
    [self refreshDataFromPasteboard];
    
    __weak typeof(self) wself = self;
    self.pasteboardCheckTimer = [NSTimer scheduledTimerWithTimeInterval:1 repeats:YES block:^(NSTimer * _Nonnull timer) {
        NSInteger current = [[UIPasteboard generalPasteboard] changeCount];
        if(current != wself.pasteboardChangeCount) {
            wself.pasteboardChangeCount = current;
            
            // pasteboard changed
            [self refreshDataFromPasteboard];
        }
    }];
}

- (void)viewDidAppear:(BOOL)animated{
    [super viewDidAppear:animated];
    NSLog(@"appear");
    
    [self initPasteboardData];
}

- (void)viewDidDisappear:(BOOL)animated{
    [super viewDidDisappear:animated];
    NSLog(@"disappear");
    
}
- (void)dealloc{
    NSLog(@"dealloc");
}

- (void)setupUI{
    self.contentView = [[UIView alloc] init];
    [self.view addSubview:self.contentView];
    [self.contentView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.mas_equalTo(self.view);
        make.top.mas_equalTo(self.view);
        make.right.mas_equalTo(self.view);
    }];
    
    UIView *seperator = [[UIView alloc] init];
    seperator.backgroundColor = [UIColor lightGrayColor];
    [self.view addSubview:seperator];
    [seperator mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.mas_equalTo(self.view);
        make.right.mas_equalTo(self.view);
        make.top.mas_equalTo(self.contentView.mas_bottom);
        make.height.mas_equalTo(1);
    }];
    
    self.buttonView = [[UIView alloc] init];
    [self.view addSubview:self.buttonView];
    [self.buttonView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.mas_equalTo(self.view);
        make.right.mas_equalTo(self.view);
        make.bottom.mas_equalTo(self.view);
        make.height.mas_equalTo(40);
        make.top.mas_equalTo(seperator.mas_bottom);
    }];
    
    {
        self.nextKeyboardButton = [[UIButton alloc]init];
        [self.nextKeyboardButton setTitle:NSLocalizedString(@"Next", @"Title for 'Next Keyboard' button") forState:UIControlStateNormal];
        [self.nextKeyboardButton setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
        [self.nextKeyboardButton addTarget:self action:@selector(handleInputModeListFromView:withEvent:) forControlEvents:UIControlEventAllTouchEvents];
        self.nextKeyboardButton.backgroundColor = TinyKeyboardViewColor1;
        [self.buttonView addSubview:self.nextKeyboardButton];
        
        self.tinyKeyboardButton = [[UIButton alloc]init];
        [self.tinyKeyboardButton setTitle:NSLocalizedString(@"Tiny", @"Title for 'Tiny Keyboard' button") forState:UIControlStateNormal];
        [self.tinyKeyboardButton setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
        [self.tinyKeyboardButton addTarget:self action:@selector(buttonTinyKeyboardTapped:) forControlEvents:UIControlEventTouchUpInside];
        self.tinyKeyboardButton.backgroundColor = TinyKeyboardViewColor2;
        [self.buttonView addSubview:self.tinyKeyboardButton];
        
        self.deleteButton = [[UIButton alloc]init];
        [self.deleteButton setTitle:NSLocalizedString(@"Delete", @"Title for 'Delete' button") forState:UIControlStateNormal];
        [self.deleteButton setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
        [self.deleteButton addTarget:self action:@selector(buttonBackwardTapped:) forControlEvents:UIControlEventTouchUpInside];
        self.deleteButton.backgroundColor = TinyKeyboardViewColor1;
        [self.buttonView addSubview:self.deleteButton];
        
        self.returnButton = [[UIButton alloc]init];
        [self.returnButton setTitle:NSLocalizedString(@"Return", @"Title for 'Return' button") forState:UIControlStateNormal];
        [self.returnButton setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
        [self.returnButton addTarget:self action:@selector(buttonReturnTapped:) forControlEvents:UIControlEventTouchUpInside];
        self.returnButton.backgroundColor = TinyKeyboardViewColor2;
        [self.buttonView addSubview:self.returnButton];
        
        BOOL needSwitchKey = YES;
        if (@available(iOS 11.0,*)) {
            needSwitchKey = [self needsInputModeSwitchKey];
        }
        
        if(needSwitchKey){
            [self.nextKeyboardButton mas_makeConstraints:^(MASConstraintMaker *make) {
                make.left.mas_equalTo(self.buttonView);
                make.top.mas_equalTo(self.buttonView);
                make.bottom.mas_equalTo(self.buttonView);
            }];
            
            [self.tinyKeyboardButton mas_makeConstraints:^(MASConstraintMaker *make) {
                make.left.mas_equalTo(self.nextKeyboardButton.mas_right);
                make.top.mas_equalTo(self.buttonView);
                make.bottom.mas_equalTo(self.buttonView);
                make.width.mas_equalTo(self.nextKeyboardButton);
            }];
            
        }else{
            [self.tinyKeyboardButton mas_makeConstraints:^(MASConstraintMaker *make) {
                make.left.mas_equalTo(self.buttonView);
                make.top.mas_equalTo(self.buttonView);
                make.bottom.mas_equalTo(self.buttonView);
            }];
        }
        
        [self.deleteButton mas_makeConstraints:^(MASConstraintMaker *make) {
            make.left.mas_equalTo(self.tinyKeyboardButton.mas_right);
            make.top.mas_equalTo(self.buttonView);
            make.bottom.mas_equalTo(self.buttonView);
            make.width.mas_equalTo(self.tinyKeyboardButton);
        }];
        
        [self.returnButton mas_makeConstraints:^(MASConstraintMaker *make) {
            make.left.mas_equalTo(self.deleteButton.mas_right);
            make.top.mas_equalTo(self.buttonView);
            make.right.mas_equalTo(self.buttonView);
            make.bottom.mas_equalTo(self.buttonView);
            make.width.mas_equalTo(self.deleteButton);
        }];
    }
    
    {
        self.textLabel = [[UILabel alloc] init];
        self.textLabel.numberOfLines = 0;
        self.textLabel.lineBreakMode = NSLineBreakByWordWrapping;
        self.textLabel.textAlignment = NSTextAlignmentCenter;
        self.textLabel.font = [UIFont systemFontOfSize:10];
        [self.contentView addSubview:self.textLabel];
        [self.textLabel mas_makeConstraints:^(MASConstraintMaker *make) {
            make.left.equalTo(self.contentView.mas_left);
            make.top.equalTo(self.contentView.mas_top).offset(20);
            make.bottom.equalTo(self.contentView.mas_bottom).offset(-20);
        }];
        
        self.inputButton = [[UIButton alloc]init];
        [self.inputButton setTitle:NSLocalizedString(@"Input", @"Title for 'Input' button") forState:UIControlStateNormal];
        [self.inputButton setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
        [self.inputButton addTarget:self action:@selector(buttonInputTapped:) forControlEvents:UIControlEventTouchUpInside];
        self.inputButton.backgroundColor = TinyKeyboardViewColor1;
        [self.contentView addSubview:self.inputButton];
        [self.inputButton mas_makeConstraints:^(MASConstraintMaker *make) {
            make.top.equalTo(self.contentView.mas_top);
            make.bottom.equalTo(self.contentView.mas_bottom);
            make.right.equalTo(self.contentView.mas_right);
            make.width.mas_equalTo(120);
            make.left.equalTo(self.textLabel.mas_right).offset(20);
        }];
    }
    
    UIColor *textColor = [UIColor blackColor];
    [self.nextKeyboardButton setTitleColor:textColor forState:UIControlStateNormal];
    [self.tinyKeyboardButton setTitleColor:textColor forState:UIControlStateNormal];
    [self.deleteButton setTitleColor:textColor forState:UIControlStateNormal];
    [self.returnButton setTitleColor:textColor forState:UIControlStateNormal];
}

- (void)textWillChange:(id<UITextInput>)textInput {
    // The app is about to change the document's contents. Perform any preparation here.
}

- (void)textDidChange:(id<UITextInput>)textInput {
    // The app has just changed the document's contents, the document context has been updated.
    
}

- (void)buttonBackwardTapped:(id)sender{
    [self.textDocumentProxy deleteBackward];
}

- (void)buttonTinyKeyboardTapped:(id)sender{
    
    if (self.tinyView) {
        [self.tinyView removeFromSuperview];
        self.tinyView = nil;
        self.contentView.hidden = NO;
    } else {
        self.tinyView = [[TinyKeyboardView alloc] init];
        self.tinyView.delegate = self;
        [self.view addSubview:self.tinyView];
        [self.tinyView mas_makeConstraints:^(MASConstraintMaker *make) {
            make.edges.equalTo(self.contentView);
        }];
        self.contentView.hidden = YES;
    }
}

- (void)buttonReturnTapped:(id)sender{
    [self.textDocumentProxy insertText:@"\n"];
}

- (void)showStatusText:(NSString*)text {
    if(pthread_main_np()){
        self.textLabel.text = text;
    }else{
        dispatch_async(dispatch_get_main_queue(), ^{
            self.textLabel.text = text;
        });
    }
}

- (void)TinyKeyboardView:(TinyKeyboardView *)keyboardView characterTapped:(NSString *)character{
    [self.textDocumentProxy insertText:character];
}

- (NSArray<NSString*>*)splitIntoChars:(NSString*)str {
    NSMutableArray<NSString*> *chars = [[NSMutableArray alloc]initWithCapacity:10];
    
    for (NSUInteger idx = 0; idx < str.length; ++idx) {
        NSString *cur = [str substringWithRange:NSMakeRange(idx, 1)];
        [chars addObject:cur];
    }
    
    return chars;
}

- (void)buttonInputTapped:(id)sender{
    if(self.pasteboardString.length == 0){
        return;
    }
    
    NSArray<NSString*> *chars = [self splitIntoChars:self.pasteboardString];
    
    if(self.delayAction){
        self.delayAction.stopped = YES;
        self.delayAction = nil;
    }
    
    self.delayAction = [[ForEachWithRandomDelay alloc]init];
    self.delayAction.items = chars;
    
    __weak typeof(self) wself = self;
    self.delayAction.action = ^(NSString* str) {
        [wself.textDocumentProxy insertText:str];
    };
    
    [self.delayAction forEach];
}


@end
