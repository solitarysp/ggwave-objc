//
//  ViewController.m
//  ggwave-objc
//
//  Created by Georgi Gerganov on 24.04.21.
//

#import "ViewController.h"

#import "ggwave/ggwave.h"

#define NUM_BYTES_PER_BUFFER 16*1024

// the text message to transmit:
const char* kDefaultMessageToSend = "Hello iOS!";
NSString* selectProtocol = @"AUDIBLE_NORMAL";
// callback used to process captured audio
void AudioInputCallback(void * inUserData,
                        AudioQueueRef inAQ,
                        AudioQueueBufferRef inBuffer,
                        const AudioTimeStamp * inStartTime,
                        UInt32 inNumberPacketDescriptions,
                        const AudioStreamPacketDescription * inPacketDescs);

// callback used to playback generated audio
void AudioOutputCallback(void * inUserData,
                         AudioQueueRef outAQ,
                         AudioQueueBufferRef outBuffer);

@interface ViewController ()

@property (weak, nonatomic) IBOutlet UILabel *labelStatusInp;
@property (weak, nonatomic) IBOutlet UILabel *labelReceived;
@property (weak, nonatomic) IBOutlet UILabel *labelStatusOut;
@property (weak, nonatomic) IBOutlet UILabel *labelMessageToSend;
@property (weak, nonatomic) IBOutlet UIButton *buttonToggleCapture;

@end

@implementation ViewController

- (void)setupAudioFormat:(AudioStreamBasicDescription*)format
{
    format->mSampleRate = 48000.0;
	format->mFormatID = kAudioFormatLinearPCM;
	format->mFramesPerPacket = 1;
	format->mChannelsPerFrame = 1;
	format->mBytesPerFrame = 2;
	format->mBytesPerPacket = 2;
	format->mBitsPerChannel = 16;
	format->mReserved = 0;
	format->mFormatFlags = kLinearPCMFormatFlagIsSignedInteger;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.data = [[NSArray alloc]initWithObjects:@"AUDIBLE_NORMAL",@"AUDIBLE_FAST",@"AUDIBLE_FASTEST",@"ULTRASOUND_NORMAL",@"ULTRASOUND_FAST", @"ULTRASOUND_FASTEST", @"DT_NORMAL", @"DT_FAST"];
    self.tableView.dataSource=self;
    self.tableView.delegate=self;
    // initialize audio format

    [self setupAudioFormat:&stateInp.dataFormat];
    [self setupAudioFormat:&stateOut.dataFormat];

    // initialize the GGWave instances:

    // RX
    {
        ggwave_Parameters parameters = ggwave_getDefaultParameters();

        parameters.sampleFormatInp = GGWAVE_SAMPLE_FORMAT_I16;
        parameters.sampleFormatOut = GGWAVE_SAMPLE_FORMAT_I16;

        stateInp.ggwaveId = ggwave_init(parameters);

        printf("GGWave capture instance initialized - instance id = %d\n", stateInp.ggwaveId);
    }

    // TX
    {
        ggwave_Parameters parameters = ggwave_getDefaultParameters();

        parameters.sampleFormatInp = GGWAVE_SAMPLE_FORMAT_I16;
        parameters.sampleFormatOut = GGWAVE_SAMPLE_FORMAT_I16;

        stateOut.ggwaveId = ggwave_init(parameters);

        printf("GGWave playback instance initialized - instance id = %d\n", stateOut.ggwaveId);
    }

    // UI

    stateInp.labelReceived = _labelReceived;
    stateOut.labelStatus = _labelStatusOut;
    _labelMessageToSend.text = [@"Message to send: " stringByAppendingString:[NSString stringWithFormat:@"%s", kDefaultMessageToSend]];
}


- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section{
    
    return [self.data count];
    
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath{
    
    
    static NSString *simpleTableIdentifier = @"cell";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:simpleTableIdentifier];
    
    
    
    if (cell == nil) {
        
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:simpleTableIdentifier];
        
    }
    
    
    cell.textLabel.text = [self.data objectAtIndex:indexPath.row] ;
    
    //cell.textLabel.font = [UIFont systemFontOfSize:11.0];
    

    return cell;
    
    
    
}





- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath{
    
    UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:indexPath];
    selectProtocol = cell.textLabel.text;
  
}
- (void) updateConfig:(NSString*)selectProtocol {
    if(selectProtocol == @"AUDIBLE_NORMAL"){
        ggwave_changeConfigTxProtocol(40, 9, 3);
    }
    if(selectProtocol== @"AUDIBLE_FAST"){
        ggwave_changeConfigTxProtocol(40, 6, 3);
    }
    if(selectProtocol == @"AUDIBLE_FASTEST"){
        ggwave_changeConfigTxProtocol(40, 3, 3);
    }
    if(selectProtocol == @"ULTRASOUND_NORMAL"){
        ggwave_changeConfigTxProtocol(320, 9, 3);
        printf("change config \n");
    }
    
    if(selectProtocol == @"ULTRASOUND_FAST"){
        ggwave_changeConfigTxProtocol(320, 6, 3);
        printf("change config \n");
    }
    
    if(selectProtocol == @"ULTRASOUND_FASTEST"){
        ggwave_changeConfigTxProtocol(320, 3, 3);
        printf("change config \n");
    }
    
    if(selectProtocol == @"DT_NORMAL"){
        ggwave_changeConfigTxProtocol(24, 9, 1);
        printf("change config \n");
    }
    
    if(selectProtocol == @"DT_FAST"){
        ggwave_changeConfigTxProtocol(24, 6, 1);
        printf("change config \n");
    }
}
-(IBAction) stopCapturing
{
    printf("Stop capturing\n");

    _labelStatusInp.text = @"Status: Idle";
    _labelReceived.text = @"Received: ";

    stateInp.isCapturing = false;

    AudioQueueStop(stateInp.queue, true);
    for (int i = 0; i < NUM_BUFFERS; i++) {
        AudioQueueFreeBuffer(stateInp.queue, stateInp.buffers[i]);
    }

    AudioQueueDispose(stateInp.queue, true);
}

- (IBAction)toggleCapture:(id)sender {
    if (stateInp.isCapturing) {
        [self stopCapturing];
        [sender setTitle:@"Start Capturing" forState:UIControlStateNormal];

        return;
    }

    // initiate audio capturing
    // the GGWave analysis is performed in the capture callback

    printf("Start capturing\n");

    OSStatus status = AudioQueueNewInput(&stateInp.dataFormat,
                                         AudioInputCallback,
                                         &stateInp,
                                         CFRunLoopGetCurrent(),
                                         kCFRunLoopCommonModes,
                                         0,
                                         &stateInp.queue);

    if (status == 0) {
        for (int i = 0; i < NUM_BUFFERS; i++) {
            AudioQueueAllocateBuffer(stateInp.queue, NUM_BYTES_PER_BUFFER, &stateInp.buffers[i]);
            AudioQueueEnqueueBuffer (stateInp.queue, stateInp.buffers[i], 0, NULL);
        }

        stateInp.isCapturing = true;
        status = AudioQueueStart(stateInp.queue, NULL);
        if (status == 0) {
            _labelStatusInp.text = @"Status: Capturing";
            [sender setTitle:@"Stop Capturing" forState:UIControlStateNormal];
        }
    }

    if (status != 0) {
        [self stopCapturing];
    }
}

-(IBAction) stopPlayback
{
    printf("Stop playback\n");

    _labelStatusOut.text = @"Status: Idle";

    stateOut.isPlaying = false;

    for (int i = 0; i < NUM_BUFFERS; i++) {
        AudioQueueFreeBuffer(stateOut.queue, stateOut.buffers[i]);
    }

    AudioQueueDispose(stateOut.queue, true);
}


- (IBAction)togglePlayback:(id)sender {
    if (stateOut.isPlaying) {
        [self stopPlayback];
        [sender setTitle:@"Send Message" forState:UIControlStateNormal];

        return;
    }
    [self updateConfig:(selectProtocol)];
    // prepare audio message using GGWave
    {
        kDefaultMessageToSend=self.textFieldData.text.UTF8String;
        const char * payload = kDefaultMessageToSend;
        const int len = (int) strlen(payload);

         const int n = ggwave_encode(stateOut.ggwaveId, payload, len, GGWAVE_TX_PROTOCOL_CUSTOM_0, 10, NULL, 1);

         stateOut.waveform = [NSMutableData dataWithLength:sizeof(char)*n];

         const int ret = ggwave_encode(stateOut.ggwaveId, payload, len, GGWAVE_TX_PROTOCOL_CUSTOM_0, 10, [stateOut.waveform mutableBytes], 0);

        if (2*ret != n) {
            printf("failed to encode the message '%s', n = %d, ret = %d\n", payload, n, ret);
            return;
        }

        stateOut.offset = 0;
        stateOut.totalBytes = n;
    }

    // initiate playback
    _labelMessageToSend.text = [@"Message to send: " stringByAppendingString:[NSString stringWithFormat:@"%s", kDefaultMessageToSend]];
    printf("Send message\n");

    OSStatus status = AudioQueueNewOutput(&stateOut.dataFormat,
                                          AudioOutputCallback,
                                          &stateOut,
                                          CFRunLoopGetCurrent(),
                                          kCFRunLoopCommonModes,
                                          0,
                                          &stateOut.queue);

    if (status == 0) {
        stateOut.isPlaying = true;
        for (int i = 0; i < NUM_BUFFERS && stateOut.isPlaying; i++) {
            AudioQueueAllocateBuffer(stateOut.queue, NUM_BYTES_PER_BUFFER, &stateOut.buffers[i]);
            AudioOutputCallback(&stateOut, stateOut.queue, stateOut.buffers[i]);
        }

        status = AudioQueueStart(stateOut.queue, NULL);
        if (status == 0) {
            _labelStatusOut.text = @"Status: Playing audio";
        }
    }

    if (status != 0) {
        [self stopPlayback];
    }
}

@end


//
// Callback implmentation
//

void AudioInputCallback(void * inUserData,
                        AudioQueueRef inAQ,
                        AudioQueueBufferRef inBuffer,
                        const AudioTimeStamp * inStartTime,
                        UInt32 inNumberPacketDescriptions,
                        const AudioStreamPacketDescription * inPacketDescs)
{
	StateInp * stateInp = (StateInp*)inUserData;

    if (!stateInp->isCapturing) {
        printf("Not capturing, returning\n");
        return;
    }

    char decoded[256];

    // analyze captured audio
    int ret = ggwave_decode(stateInp->ggwaveId, (char *)inBuffer->mAudioData, inBuffer->mAudioDataByteSize, decoded);

    // check if a message has been received
    if (ret > 0) {
        stateInp->labelReceived.text = [@"Received: " stringByAppendingString:[NSString stringWithFormat:@"%s", decoded]];
    }

    // put the buffer back in the queue
    AudioQueueEnqueueBuffer(stateInp->queue, inBuffer, 0, NULL);
}

void AudioOutputCallback(void * inUserData,
                         AudioQueueRef outAQ,
                         AudioQueueBufferRef outBuffer)
{
	StateOut* stateOut = (StateOut*)inUserData;
    if (!stateOut->isPlaying) {
        printf("Not playing, returning\n");
        return;
    }

    int nRemainingBytes = stateOut->totalBytes - stateOut->offset;

    // check if there is any audio left to play
    if (nRemainingBytes > 0) {
        int nBytesToPush = MIN(nRemainingBytes, NUM_BYTES_PER_BUFFER);

        memcpy(outBuffer->mAudioData, [stateOut->waveform mutableBytes] + stateOut->offset, nBytesToPush);
        outBuffer->mAudioDataByteSize = nBytesToPush;

        OSStatus status = AudioQueueEnqueueBuffer(stateOut->queue, outBuffer, 0, NULL);
        if (status != 0) {
            printf("Failed to enqueue audio data\n");
        }

        stateOut->offset += nBytesToPush;
    } else {
        // no audio left - stop playback
        if (stateOut->isPlaying) {
            printf("Stopping playback\n");
            AudioQueueStop(stateOut->queue, false);
            stateOut->isPlaying = false;
            stateOut->labelStatus.text = @"Status: Idle";
        }

        AudioQueueFreeBuffer(stateOut->queue, outBuffer);
    }
}
