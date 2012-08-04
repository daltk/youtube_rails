class VideosController < ApplicationController
  layout 'whootube'

  CONDITIONS = ['status_code IN (?)', [2,3]] # all processed videos (including failures)

  # GET /videos
  # GET /videos.xml
  def index
    # Only display videos that have been processed 
    Video.with_scope(:find => { :conditions => CONDITIONS }) do
      if params[:tag]
        @videos = Video.find_tagged_with(params[:tag], :include => [:tags])
      else
        @videos = Video.find(:all)
      end
    end

    # Only show tags for videos that have been processed
    Tag.with_scope(:find => { :conditions => CONDITIONS }) do
      @tags = Video.tag_counts
    end

    respond_to do |format|
      format.html # index.rhtml
      format.xml  { render :xml => @videos.to_xml }
    end
  end

  def queued
    @videos = Video.find(:all, :conditions => ['status_code IN (?)', [0,1]]) # videos that are queued or currently processing

    respond_to do |format|
      format.html # index.rhtml
      format.xml  { render :xml => @videos.to_xml }
    end
  end

  def thumbnail
    begin
      video = Video.find_by_hashed_name(params[:id])
    rescue ActiveRecord::RecordNotFound
      send_file(RAILS_ROOT + "/public/images/video_not_found.png", :filename => "video_not_found.png", :type => "image/png", :disposition => "inline")
    else
      if video.status_code == 3 # failed
        send_file(RAILS_ROOT + "/public/images/video_invalid_format.png", :filename => "video_invalid_format.png", :type => "image/png", :disposition => "inline")
      elsif not File.exists?(video.full_path_to_thumbnail)
        send_file(RAILS_ROOT + "/public/images/video_no_thumb.png", :filename => video.filename+"_thumbnail.png", :type => "image/png", :disposition => "inline")
      else # success
        send_file(video.full_path_to_thumbnail, :filename => video.filename+"_thumbnail.jpg", :type => "image/jpeg", :disposition => "inline")
      end
    end  
  end

  def stream
    # Many players require that we GET an URL ending in .flv or they will not playback the video
    hashed_name = params[:id].gsub('.flv', '')
    video = Video.find_by_hashed_name_and_status_code(hashed_name, 2) # videos that have been processed successfully
    if video
      send_file(video.full_path_to_video, :filename => video.title+'.flv', :type => 'video/x-flv', :disposition => 'inline')
    else
      render :nothing => true, :status => 404
    end
  end
  
  # GET /videos/1
  # GET /videos/1.xml
  def show
    @video = Video.find_by_hashed_name(params[:id])

    respond_to do |format|
      format.html # show.rhtml
      format.xml  { render :xml => @video.to_xml }
    end
  end

  # GET /videos/new
  def new
    @video = Video.new
  end

  # GET /videos/1;edit
  def edit
    @video = Video.find_by_hashed_name(params[:id])
  end

  # POST /videos
  # POST /videos.xml
  def create
    @video = Video.new(params[:video])

    respond_to do |format|
      if @video.save
        begin
          # Queue the video for background processing
          MiddleMan.new_worker(:class => :video_worker, :job_key => @video.filename)
        rescue
          # Backgroundrb server is down
        end
        flash[:notice] = 'Video was successfully uploaded and is queued for processing.'
        format.html { redirect_to video_url(@video.hashed_name) }
        format.xml  { head :created, :location => video_url(@video.hashed_name) }
      else
        format.html { render :action => "new" }
        format.xml  { render :xml => @video.errors.to_xml }
      end
    end
  end

  # PUT /videos/1
  # PUT /videos/1.xml
  def update
    @video = Video.find_by_hashed_name(params[:id])

    respond_to do |format|
      if @video.update_attributes(params[:video])
        flash[:notice] = 'Video was successfully updated.'
        format.html { redirect_to video_url(@video.hashed_name) }
        format.xml  { head :ok }
      else
        format.html { render :action => "edit" }
        format.xml  { render :xml => @video.errors.to_xml }
      end
    end
  end

  # DELETE /videos/1
  # DELETE /videos/1.xml
  def destroy
    @video = Video.find_by_hashed_name(params[:id])
    @video.destroy

    respond_to do |format|
      format.html { redirect_to videos_url }
      format.xml  { head :ok }
    end
  end
end
