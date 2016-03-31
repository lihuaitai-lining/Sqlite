//
//  ViewController.m
//  Sqlit
//
//  Created by 李怀泰 on 16/3/23.
//  Copyright © 2016年 李怀泰. All rights reserved.
//

#import "ViewController.h"
#import <sqlite3.h>
#import <MJRefresh.h>

#define SCR_WIDTH [UIScreen mainScreen].bounds.size.width
#define SCR_HEIGHT [UIScreen mainScreen].bounds.size.height

#define DATA_FILE @"sqlit"

@interface ViewController ()<UITableViewDataSource, UITableViewDelegate, UITextFieldDelegate, UIAlertViewDelegate>
@property (nonatomic, strong) UITableView * tableView;
@property (nonatomic, strong) NSMutableArray * dataArray;
@property (nonatomic, assign) sqlite3 * dataBase;
@property (nonatomic, strong) UILabel * nameLabel;
@property (nonatomic, strong) UITextField * textField;
@property (nonatomic, strong) UIButton * saveButton;
@property (nonatomic, copy)   NSString * replaceString;//要被替换的
@end

@implementation ViewController

#pragma mark - init

-(UITableView *)tableView{
    if (!_tableView) {
        _tableView = [[UITableView alloc]initWithFrame:[UIScreen mainScreen].bounds];
        _tableView.dataSource = self;
        _tableView.delegate   = self;
        _tableView.tableHeaderView = [self createTableViewHeaderView];
        _tableView.tableFooterView = [[UIView alloc]init];
    }
    return _tableView;
}

-(NSMutableArray *)dataArray{
    if (!_dataArray) {
        _dataArray = [NSMutableArray array];
    }
    return _dataArray;
}

#pragma mark - lifeCycle

- (void)viewDidLoad {
    [super viewDidLoad];
    self.navigationItem.title = @"sqlite的操作";
    self.dataArray = [self getDataFromSqlit];
    [self.view addSubview:self.tableView];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]initWithBarButtonSystemItem:UIBarButtonSystemItemEdit target:self action:@selector(startEditing:)];
    
    __unsafe_unretained UITableView * tableView = self.tableView;
    // 下拉刷新
    tableView.mj_header= [MJRefreshNormalHeader headerWithRefreshingBlock:^{
        // 模拟延迟加载数据，因此2秒后才调用（真实开发中，可以移除这段gcd代码）
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            // 结束刷新
            [tableView.mj_header endRefreshing];
        });
    }];
    
    // 设置自动切换透明度(在导航栏下面自动隐藏)
    tableView.mj_header.automaticallyChangeAlpha = YES;
    
    // 上拉刷新
    tableView.mj_footer = [MJRefreshBackNormalFooter footerWithRefreshingBlock:^{
        // 模拟延迟加载数据，因此2秒后才调用（真实开发中，可以移除这段gcd代码）
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            // 结束刷新
            [tableView.mj_footer endRefreshing];
        });
    }];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section{
    return self.dataArray.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath{
    
    UITableViewCell * cell = [[UITableViewCell alloc]initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"cell"];
    cell.textLabel.text = self.dataArray[indexPath.row];
    return cell;
}

#pragma mark - UITableViewDelegate

//设置cell为可编辑状态
-(BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath{
    return YES;
}

//定义编辑样式
- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath{
    return UITableViewCellEditingStyleDelete;
}

//进入编辑模式按下出现的编辑按钮后
-(void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath{
    [self.tableView setEditing:YES animated:YES];
    UITableViewCell * cell = [self.tableView cellForRowAtIndexPath:indexPath];
    NSString * string = cell.textLabel.text;
    NSLog(@"%@", string);
    [self deleteData:string];
}

- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath{
    return YES;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath{
    UITableViewCell * cell = [self.tableView cellForRowAtIndexPath:indexPath];
    [self changeName:cell.textLabel.text];
    
}

//点击cell更换名字
-(void) changeName:(NSString *) string{
    _replaceString = string;
    UIAlertView * alertView = [[UIAlertView alloc]initWithTitle:@"请输入你要替换的名字" message:nil delegate:self cancelButtonTitle:@"取消" otherButtonTitles:@"确定", nil];
    [alertView setAlertViewStyle:UIAlertViewStylePlainTextInput];
    [alertView textFieldAtIndex:0];
    [alertView show];
}

#pragma mark - view

-(UIView *) createTableViewHeaderView{
    UIView * headerView = [[UIView alloc]initWithFrame:CGRectMake(0, 0, SCR_WIDTH, 50)];
    _nameLabel = [[UILabel alloc]initWithFrame:CGRectMake(20, 20, 50, 20)];
    _nameLabel.text = @"姓名";
    _nameLabel.font = [UIFont systemFontOfSize:15];
    [_nameLabel sizeToFit];
    [headerView addSubview:_nameLabel];
    
    _textField = [[UITextField alloc]initWithFrame:CGRectMake(CGRectGetMaxX(_nameLabel.frame) + 5, 20, 100, 20) ];
    _textField.borderStyle = UITextBorderStyleLine;
    _textField.placeholder = @"输入姓名";
    _textField.font = [UIFont systemFontOfSize:15];
    _textField.delegate = self;
    [_textField addTarget:self action:@selector(textFieldChange:) forControlEvents:UIControlEventEditingChanged];
    [headerView addSubview:_textField];
    
    _saveButton = [UIButton buttonWithType:UIButtonTypeCustom];
    _saveButton.frame = CGRectMake(CGRectGetMaxX(_textField.frame) + 20, 20, 50, 20);
    _saveButton.titleLabel.font = [UIFont systemFontOfSize:15];
    _saveButton.backgroundColor = [UIColor grayColor];
    _saveButton.enabled = NO;
    [_saveButton setTitle:@"保存" forState:UIControlStateNormal];
    [_saveButton addTarget:self action:@selector(saveButtonClick:) forControlEvents:UIControlEventTouchUpInside];
    [headerView addSubview:_saveButton];
    return headerView;
}

#pragma mark - UITextFieldDelegate

-(void) textFieldChange:(UITextField *) textField{
    if (textField.text.length == 0) {
        _saveButton.enabled = NO;
        _saveButton.backgroundColor = [UIColor grayColor];
    }else{
        _saveButton.enabled = YES;
        _saveButton.backgroundColor = [UIColor cyanColor];
    }}

#pragma mark - click

//保存按钮的点击
-(void) saveButtonClick:(id) sender{
    [self insertDataToSqlite];
}

//编辑按钮的点击
-(void) startEditing:(UIBarButtonItem *) sender{
    self.tableView.editing = !self.tableView.editing;
    if (self.tableView.editing) {
        [self.tableView setEditing:YES animated:YES];
    }else{
        [self.tableView setEditing:NO animated:YES];
    }    
}

#pragma mark - UIAlertViewDelegate

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (buttonIndex == 1) {
        UITextField * textFiled = [alertView textFieldAtIndex:0];
        NSLog(@"%@", textFiled.text);
        [self upDateData:textFiled.text replaceName:_replaceString];
    }
}

#pragma mark - sqlit

//判断数据库是否打开
-(BOOL)judgeSqliteOpenOrNo{
    NSString * filePath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
    NSString * fileName = [filePath stringByAppendingString:DATA_FILE];
    if (sqlite3_open([fileName UTF8String], &_dataBase) == SQLITE_OK) {
        return YES;
    }
    return NO;
}

//添加数据
-(void) insertDataToSqlite{
    if ([self judgeSqliteOpenOrNo]) {
        char * sqlStr = "create table if not exists person(name text);";
        char * error;
        sqlite3_stmt * statement;
        if (sqlite3_exec(_dataBase, sqlStr, NULL, NULL, &error) == SQLITE_OK) {
            char * sql = "insert into person(name) values(?)";
            if (sqlite3_prepare_v2(_dataBase, sql, -1, &statement, NULL) == SQLITE_OK) {
                sqlite3_bind_text(statement, 1, [_textField.text UTF8String], -1, NULL);
                if ((sqlite3_step(statement) == SQLITE_DONE)) {
                    NSLog(@"插入成功");
                    [self.tableView reloadData];
                }else{
                    NSLog(@"插入失败");
                }
            }
        }
        sqlite3_finalize(statement);
        sqlite3_close(_dataBase);
    }else{
        NSLog(@"打开数据库失败");
    }
    self.textField.text = @"";
}

//取出所有数据
-(NSMutableArray *) getDataFromSqlit{
    NSMutableArray * array = [NSMutableArray array];
    if ([self judgeSqliteOpenOrNo]) {
        //查找
        char * sql = "select name from person";
        sqlite3_stmt * statement;
        if (sqlite3_prepare_v2(_dataBase, sql, -1, &statement, NULL) == SQLITE_OK) {
            while (sqlite3_step(statement) == SQLITE_ROW) {
                char * field1 = (char *) sqlite3_column_text(statement, 0);
                NSString * fieldString = [[NSString alloc]initWithUTF8String:field1];
                [array addObject:fieldString];
            }
        }else{
            NSLog(@"查找语句错误");
        }
        sqlite3_finalize(statement);
        sqlite3_close(_dataBase);
    }
    return array;
}

//删除
-(void) deleteData:(NSString *) string{
    if ([self judgeSqliteOpenOrNo]) {
        NSString * string1 = [NSString stringWithFormat:@"delete from person where name = '%@'", string];
        sqlite3_stmt * smt;
        int result = sqlite3_prepare(_dataBase, [string1 UTF8String], -1, &smt, NULL);
        if (result == SQLITE_OK) {
            sqlite3_bind_int(smt, 1, 58);
            if (sqlite3_step(smt) == SQLITE_DONE) {
                NSLog(@"删除成功");
                _dataArray = [self getDataFromSqlit];
                [self.tableView reloadData];
            }else{
                NSLog(@"%d", sqlite3_bind_int(smt, 1, 58));
            }
        }else{
            NSLog(@"删除语句错误");
        }
        sqlite3_finalize(smt);
        sqlite3_close(_dataBase);
    }
}

//修改
-(void) upDateData:(NSString *) newName replaceName:(NSString *) oldName{
    if ([self judgeSqliteOpenOrNo]) {
        NSString * string = [NSString stringWithFormat:@"update person set name = '%@' where name = '%@'", newName, oldName];
        sqlite3_stmt * temt;
        int result = sqlite3_prepare(_dataBase, [string UTF8String], -1, &temt, NULL);
        if (result == SQLITE_OK) {
            if (sqlite3_step(temt) == SQLITE_DONE) {
                NSLog(@"修改成功");
                _dataArray = [self getDataFromSqlit];
                [self.tableView reloadData];
            }else{
                NSLog(@"修改失败");
            }
        }else{
            NSLog(@"修改语句错误");
        }
    }
}

@end
