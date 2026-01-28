package main

import (
	"log"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"strings"
	"time"

	"github.com/pocketbase/dbx"
	"github.com/pocketbase/pocketbase"
	"github.com/pocketbase/pocketbase/core"
	"github.com/rwcarlsen/goexif/exif"
)

var dateRegexes = []*regexp.Regexp{
	regexp.MustCompile(`(\d{4})(\d{2})(\d{2})`),
}

func main() {
	app := pocketbase.New()

	app.OnRecordAfterCreateSuccess("photos").BindFunc(func(e *core.RecordEvent) error {
		filename := e.Record.GetString("file")
		if filename == "" {
			return e.Next()
		}

		dataDir := app.DataDir()
		collectionId := e.Record.Collection().Id
		recordId := e.Record.Id
		filePath := filepath.Join(dataDir, "storage", collectionId, recordId, filename)
		ext := strings.ToLower(filepath.Ext(filename))

		//BACKGROUND PROCESSING (Transcode, Optimize, Thumbnails, Proxies)
		go func() {
			currentFilePath := filePath
			currentFilename := filename
			currentExt := ext

			//AUTO-CONVERSION (AVI/MKV -> MP4)
			if currentExt == ".avi" || currentExt == ".mkv" || currentExt == ".wmv" || currentExt == ".flv" || currentExt == ".webm" {
				app.Logger().Info("Transcoding to MP4...", "file", currentFilename)
				
				newFilename := strings.TrimSuffix(currentFilename, currentExt) + ".mp4"
				newFilePath := filepath.Join(dataDir, "storage", collectionId, recordId, newFilename)

				cmd := exec.Command("ffmpeg", "-y", "-i", currentFilePath, 
					"-c:v", "libx264", "-pix_fmt", "yuv420p", "-crf", "28", "-preset", "ultrafast",
					"-c:a", "aac", "-b:a", "128k", 
					"-movflags", "faststart", 
					newFilePath)
				
				output, err := cmd.CombinedOutput()
				
				if err == nil {
					// Using Direct SQL to bypass validation errors
					_, dbErr := app.DB().NewQuery("UPDATE photos SET file={:file} WHERE id={:id}").
						Bind(dbx.Params{"file": newFilename, "id": recordId}).Execute()

					if dbErr == nil {
						os.Remove(currentFilePath)
						currentFilePath = newFilePath
						currentFilename = newFilename
						currentExt = ".mp4"
						app.Logger().Info("Transcoding complete.", "new_file", newFilename)
					} else {
						app.Logger().Error("DB Update failed", "error", dbErr)
					}
				} else {
					app.Logger().Error("Transcoding failed", "error", err, "output", string(output))
				}
			}

			// Optimize Original Videos
			// Ensure metadata is at the start for streaming
			if currentExt == ".mp4" || currentExt == ".mov" || currentExt == ".mpeg" || currentExt == ".mpg" {
				tempPath := currentFilePath + ".temp.mp4"
				if exec.Command("ffmpeg", "-y", "-v", "error", "-i", currentFilePath, "-c", "copy", "-movflags", "faststart", tempPath).Run() == nil {
					os.Rename(tempPath, currentFilePath)
				} else {
					os.Remove(tempPath)
				}
			}

			//Generate Assets (thumbs,proxies)
			thumbDir := filepath.Join(dataDir, "thumbs_static", collectionId, recordId)
			previewDir := filepath.Join(dataDir, "previews_static", collectionId, recordId)
			os.MkdirAll(thumbDir, 0755)
			os.MkdirAll(previewDir, 0755)

			thumbPath := filepath.Join(thumbDir, currentFilename+".webp")
			
			// Thumbnails (Grid) - 256px
			if isImage(currentExt) {
				exec.Command("ffmpeg", "-y", "-v", "error", "-i", currentFilePath, "-vf", "scale=256:256:force_original_aspect_ratio=decrease", "-q:v", "50", thumbPath).Run()
			} else if isVideo(currentExt) {
				if exec.Command("ffmpeg", "-y", "-v", "error", "-ss", "00:00:01", "-i", currentFilePath, "-vf", "thumbnail,scale=256:256:force_original_aspect_ratio=decrease", "-frames:v", "1", "-q:v", "50", thumbPath).Run() != nil {
					// Fallback to frame 0
					exec.Command("ffmpeg", "-y", "-v", "error", "-i", currentFilePath, "-vf", "thumbnail,scale=256:256:force_original_aspect_ratio=decrease", "-frames:v", "1", "-q:v", "50", thumbPath).Run()
				}
			}

			// Previews / Proxies (Sharing & Fullscreen)
			if isImage(currentExt) {
				// Image Preview: 1280px WebP
				previewPath := filepath.Join(previewDir, currentFilename+".webp")
				exec.Command("ffmpeg", "-y", "-v", "error", "-i", currentFilePath, "-vf", "scale=1280:1280:force_original_aspect_ratio=decrease", "-q:v", "75", previewPath).Run()
			
			} else if isVideo(currentExt) {
				// VIDEO PROXY: 720p MP4 for fast sharing/playback
				// Naming convention: video.mp4 -> video.mp4_proxy.mp4
				proxyPath := filepath.Join(previewDir, currentFilename+"_proxy.mp4")
				
				app.Logger().Info("Generating video proxy...", "file", currentFilename)
				
				// -vf scale=-2:720, Resize height to 720p, keep aspect ratio
				// -crf 28 -> Lower quality (smaller size)
				// -preset ultrafast -> Burn less CPU
				proxyCmd := exec.Command("ffmpeg", "-y", "-i", currentFilePath,
					"-c:v", "libx264", "-pix_fmt", "yuv420p", "-crf", "28", "-preset", "ultrafast",
					"-vf", "scale=-2:720", 
					"-c:a", "aac", "-b:a", "96k",
					"-movflags", "faststart",
					proxyPath)
				
				if err := proxyCmd.Run(); err != nil {
					app.Logger().Error("Proxy generation failed", "error", err)
				} else {
					app.Logger().Info("Proxy generated successfully", "path", proxyPath)
				}
			}
		}()

		//metadata
		var takenAt time.Time
		foundDate := false

		if isImage(ext) {
			f, err := os.Open(filePath)
			if err == nil {
				x, err := exif.Decode(f)
				if err == nil {
					if tm, err := x.DateTime(); err == nil {
						takenAt = tm
						foundDate = true
					}
				}
				f.Close()
			}
		}

		if !foundDate && (isVideo(ext) || ext == ".avi" || ext == ".mkv") {
			cmd := exec.Command("ffprobe", "-v", "quiet", "-show_entries", "format_tags=creation_time", "-of", "default=noprint_wrappers=1:nokey=1", filePath)
			out, err := cmd.Output()
			if err == nil && len(out) > 0 {
				dateStr := strings.TrimSpace(string(out))
				if tm, err := time.Parse(time.RFC3339, dateStr); err == nil {
					takenAt = tm
					foundDate = true
				} else if tm, err := time.Parse("2006-01-02 15:04:05", dateStr); err == nil {
					takenAt = tm
					foundDate = true
				}
			}
		}

		if !foundDate {
			for _, regex := range dateRegexes {
				matches := regex.FindStringSubmatch(filename)
				if len(matches) == 4 {
					dateStr := matches[1] + "-" + matches[2] + "-" + matches[3] + "T12:00:00Z"
					if tm, err := time.Parse(time.RFC3339, dateStr); err == nil {
						takenAt = tm
						foundDate = true
						break
					}
				}
			}
		}

		if foundDate {
			now := time.Now().Add(24 * time.Hour) 
			if takenAt.After(now) {
				foundDate = false 
			}
		}

		if foundDate {
			e.Record.Set("taken_at", takenAt)
			app.Save(e.Record)
		}

		return e.Next()
	})

	if err := app.Start(); err != nil {
		log.Fatal(err)
	}
}

func isImage(ext string) bool {
	return ext == ".jpg" || ext == ".jpeg" || ext == ".png" || ext == ".webp" || ext == ".tiff" || ext == ".gif"
}

func isVideo(ext string) bool {
	return ext == ".mp4" || ext == ".mov" || ext == ".avi" || ext == ".3gp" || ext == ".webm" || ext == ".mkv" || ext == ".mpeg" || ext == ".mpg"
}
