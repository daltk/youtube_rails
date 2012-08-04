require 'digest/sha1'

class Video < ActiveRecord::Base
  attr_accessor :file
  validates_presence_of :file, :if => Proc.new { |video| video.new_record? } # don't require a new video if we, say, update the description

  before_create :set_filename
  after_create :queue_or_destroy

  before_destroy :delete_files

  STATUS_CODE = [
    [ 0, 'Queued' ],
    [ 1, 'Processing' ],
    [ 2, 'Ready' ],
    [ 3, 'Failed' ]
  ]

  acts_as_taggable

  validates_presence_of :title
  validates_inclusion_of :status_code, :in => STATUS_CODE.map { |sc| sc[0] }

  # Return a human-readable status code
  def status
    STATUS_CODE.find { |sc| sc[0] == status_code }[1]
  end

  ## Store the videos in a directory seperate from the public one.
  ## This allows for access control (which is not implemented here).

  def full_path_to_queue
    RAILS_ROOT + '/videos/queue/' + filename + '.orginal'
  end
  
  def full_path_to_video
    RAILS_ROOT + '/videos/' + filename + '.flv'
  end
  
  def full_path_to_thumbnail
    RAILS_ROOT + '/videos/' + filename + '_thumbnail.jpg'
  end

  ## Use a salted hashed named to prevent name clashes and add a dash of security.
  ## Security through obscurity? Yeah, YouTube does that too. :-)

  def filename
    hashed_name
  end

  def filename=(name)
    salt = [Array.new(6){rand(256).chr}.join].pack('m').chomp
    self.hashed_name = Video.get_hash(name, salt)
  end

protected

  def set_filename
    self.filename = file.original_filename if file.respond_to?(:original_filename)
  end

  # Only queue the file if the database write and the I/O operations were successful.
  # Otherwise, immediately remove this video from the database and present an error.
  def queue_or_destroy
    if !new_record? # record not new anymore --> record has been saved
      begin
        File.open(full_path_to_queue, "wb") { |f| f.write(file.read) }
      rescue
        errors.add(:file, 'uploaded failed')
        destroy
        return false
      end
    end
  end

  # Clean up any files that are lingering.
  def delete_files
    begin
      File.delete(full_path_to_video) if File.exists?(full_path_to_video)
      File.delete(full_path_to_thumbnail) if File.exists?(full_path_to_thumbnail)
      File.delete(full_path_to_queue) if File.exists?(full_path_to_queue)
    rescue
      true
    end
  end

  def self.get_hash(password, salt)
    Digest::SHA1.hexdigest(password + salt)
  end
end
