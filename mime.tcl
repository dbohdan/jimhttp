# MIME type detection by file extension.
# Copyright (C) 2014 Danyil Bohdan.
# License: MIT
set mime::byExtension {
	.c      text/plain
	.css    text/css
	.csv	text/csv
	.gif	image/gif
	.gz		application/gzip
	.h      text/plain
	.htm	text/html
	.html	text/html
	.jpg	image/jpeg
	.jpeg	image/jpeg
	.js		application/javascript
	.json   application/json
	.pdf    application/pdf
	.png	image/png
	.ps     application/postscript
	.sh     text/plain
	.tcl    text/plain
	.txt 	text/plain
	.xhtml  application/xhtml+xml
	.xml    application/xml
	.zip	application/zip
}

proc mime::type {filename} {
	global mime::byExtension
	set ext [file extension $filename]
	if {[dict exists $mime::byExtension $ext]} {
		return $mime::byExtension($ext)
	} else {
		return application/octet-stream
	}
}
