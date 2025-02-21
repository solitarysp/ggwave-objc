//
//  ViewController.h
//  ggwave-objc
//
//  Created by Georgi Gerganov on 24.04.21.
//

#import <UIKit/UIKit.h>

#import <AVFoundation/AVFoundation.h>
#import <AudioToolbox/AudioQueue.h>

#define NUM_BUFFERS 3

typedef struct
{
    int ggwaveId;
    bool isCapturing;
    UILabel * labelReceived;
    UILabel * labelLengthReceived;
    UILabel * labelLength;
    UITextField * textRandomLength;
    UILabel *labelTimeReceive;
    AudioQueueRef queue;
    AudioStreamBasicDescription dataFormat;
    AudioQueueBufferRef buffers[NUM_BUFFERS];
} StateInp;

typedef struct
{
    bool isPlaying;
    int ggwaveId;
    int offset;
    int totalBytes;
    NSMutableData * waveform;
    UILabel * labelStatus;
    UILabel * labelTimeSend;
    UILabel * labeleTotalTime;
    AudioQueueRef queue;
    AudioStreamBasicDescription dataFormat;
    AudioQueueBufferRef buffers[NUM_BUFFERS];
} StateOut;

@interface ViewController : UIViewController<UITableViewDelegate,UITableViewDataSource>
{
    StateInp stateInp;
    StateOut stateOut;
}
@property (weak, nonatomic) IBOutlet UITableView *tableView;
@property(strong , nonatomic) NSArray *data;
@property (nonatomic, retain) IBOutlet UITextField *textFieldData;
@end
