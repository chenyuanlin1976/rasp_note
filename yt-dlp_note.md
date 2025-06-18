# refer to https://github.com/yt-dlp/yt-dlp

1. Get the downloadable video and audio format wiht -F
`yt-dlp_linux_aarch64 -F https://youtu.be/4wKtY_xZIPk`

2. You can filter the format with grep, such as:
`./yt-dlp_linux_aarch64 -F https://youtu.be/4wKtY_xZIPk | grep webm`

3. download the specified format from Youtube URL with -f
`./yt-dlp_linux_aarch64 -f 315+251 https://youtu.be/4wKtY_xZIPk`

4. download the specified sections from Youtube URL with --download-sections
`./yt-dlp_linux_aarch64 -f 313+251 --download-sections "*00:00-03:00" https://youtu.be/SMKPKGW083c`

