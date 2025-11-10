# ffmpeg command

`ffmpeg -h`

## trim video file

+ -ss time_off: set the start time offset
+ -to time_stop: record or transcode stop time
+ -t duration: record or transcode "duration" seconds of audio/video
+ -i infile
+ -c codec: codec name
+ -s size: set frame size (WxH or abbreviation)

`ffmpeg -ss 00:00:30 -t  00:00:10 -i input.mp4 -c copy output.mp4`  
`ffmpeg -ss 00:01:00 -to 00:02:00 -i input.mp4 -c copy output.mp4`  

`ffmpeg -ss 00:01:00 -to 00:02:00 -i input.mp4 output.mp4`  
`ffmpeg -ss 00:01:00 -to 00:02:00 -i input.mp4 -s 1920x1080 output.mp4`  

`ffmpeg -ss 00:28:16 -i test.mp4 -vcodec copy -acodec copy test_new.mp4`  
`ffmpeg -ss 00:28:16 -i test.mp4 -c:v copy -c:a copy test_new.mp4`  
