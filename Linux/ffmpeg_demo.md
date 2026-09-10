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

## Extracting Frames

+ Extracting All Frames: `ffmpeg -i input.mp4 frame%04d.png`
+ Extracting Frames at a Specific Frame Rate: `ffmpeg -i input.mp4 -vf "fps=10" frame%04d.png`
+ Extracting Frames at Specific Intervals: `ffmpeg -i input.mp4 -r 1/5 frame%04d.png`
+ Extracting a Single Frame at a Specific Timestamp: `ffmpeg -ss 00:01:00 -i input.mp4 -frames:v 1 output.png`
+ Extracting a Range of Frames: `ffmpeg -ss 00:00:05 -to 00:00:08 -i input.mp4 frame%04d.png`

## To convert a sequence of PNG images into an MP4 video using FFmpeg

`ffmpeg -framerate 60 -i image%03d.png -c:v libx264 -pix_fmt yuv420p output.mp4`

+ -framerate 60: Sets the output video's frame rate to 60 frames per second. Adjust this value as needed for your desired video speed.
+ -i image%03d.png: Specifies the input image sequence.  
   image: The common prefix of your image files.  
   %03d: A placeholder for the sequential numbering. 03d indicates a three-digit number with leading zeros (e.g., 001, 002).  
   .png: The file extension of your images.  
+ -c:v libx264: Specifies the video codec to use, in this case, H.264, which is widely compatible.
+ -pix_fmt yuv420p: Sets the pixel format to YUV 4:2:0, ensuring broader compatibility with various players and devices.
+ output.mp4: The desired name for your output MP4 video file.

### Single Image to Video

If you want to create a video from a single PNG image for a specific duration, use the -loop 1 and -t options.  
The following command creates a 10-second video from image.png

`ffmpeg -loop 1 -i image.png -c:v libx264 -t 10 -pix_fmt yuv420p output.mp4`

### Resizing/Scaling: To control the output video's resolution, use the -vf scale filter

`ffmpeg -framerate 25 -i image%03d.png -vf scale=1280:720 -c:v libx264 -pix_fmt yuv420p output.mp4`

### Audio: To add an audio track, include an additional -i option for your audio file

`ffmpeg -framerate 25 -i image%03d.png -i audio.mp3 -c:v libx264 -c:a aac -pix_fmt yuv420p -shortest output.mp4`

The -shortest option ensures the video ends when the shortest input (either video or audio) finishes.
