# wget intro

The wget command is a powerful, non-interactive command-line utility used in Linux and Unix-like operating systems to download files from the web.  
It supports protocols like HTTP, HTTPS, and FTP, making it ideal for retrieving files, mirroring websites, and automating downloads.

## Key Features & Common Options

+ `wget [URL]`: Downloads a file and saves it in the current directory with its original name.
+ `-b`: Runs the download in the background, allowing you to close the terminal or continue working.
+ `-c`: Resumes a partially downloaded file (great for large files or unstable connections).
+ `-i urls.txt`: Tells wget to read the file line-by-line and download every link sequentially.
+ `-O [filename]`: Saves the downloaded file under a different, specified filename.
+ `-r`: Downloads recursively, traversing links to download an entire directory or website.
+ `--limit-rate=[rate]`: Restricts the download speed (e.g., --limit-rate=200k) to avoid saturating your bandwidth.

## Practical Examples

1. Download a single file: `wget https://example.com/file.zip`
2. Download and save with a custom name: `wget -O custom_name.zip https://example.com/file.zip`
3. Resume a broken or interrupted download: `wget -c https://example.com/large-file.iso`
4. Mirror an entire website for offline viewing: `wget --mirror --convert-links --adjust-extension https://example.com`
