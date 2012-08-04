class VideoWorker < BackgrounDRb::Worker::RailsBase
  ## Set these to your actual configuration

  FFMPEG = "/opt/local/bin/ffmpeg"
  FLVTOOL = RAILS_ROOT + "/vendor/plugins/flvtool2-1.0.6/bin/flvtool2"

  def do_work(args)
    logger.info("==> Start converting #{@jobkey}")

    # Because we set the job key, which should be unique, to the hashed name of the video, which is also unique, we can do this:
    video = Video.find_by_hashed_name(@jobkey)
    if !video
      return fail_with("Video #{@jobkey} not found in database! Aborting.")
    end
    
    source = video.full_path_to_queue
    flv_target = video.full_path_to_video
    thumbnail_target = video.full_path_to_thumbnail
    
    video.status_code = 1 # processing
    video.save!
    
    # Convert to FLV
    success = system("#{FFMPEG} -i #{source} -s 320x240 -ar 44100 #{flv_target}")
    begin
      File.delete(source)
    rescue
      logger.warn("Unable to remove #{source} after conversion. Ignoring.")
    end
    
    if !success
      video.status_code = 3 # failed
      video.save!
      return fail_with("Unable to convert #{source} to #{flv_target}. Removing original and aborting.")
    end
    
    # ffmpeg does not inject FLV metadata and this will cause skipping back and forth the FLV to be unavailable.
    # Fix this by updating the FLV metadata, including the length.
    if !system("#{FLVTOOL} -U #{flv_target}")
      logger.warn("Unable to update FLV metadata. Ignoring.")
    end
    
    # Generate thumbnail
    if !system("#{FFMPEG} -i #{flv_target} -s 80x60 -an -ss 3 -t 00:00:03 -f mjpeg -y #{thumbnail_target}")
      logger.warn("Unable to create thumbnail #{thumbnail_target} from #{flv_target}. Ignoring.")
    end
    
    video.status_code = 2 # ready
    video.save!
    
    logger.info("==> Done converting #{source} to #{flv_target}")
    self.delete # will persist in memory otherwise
  end
  
  def fail_with(message)
    logger.error(message)
    self.delete
    return false
  end
end

VideoWorker.register # with the BackgrounDRb server
