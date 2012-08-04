# Methods added to this helper will be available to all templates in the application.
module ApplicationHelper

  # Adapted from http://www.juixe.com/techknow/index.php/2006/07/15/acts-as-taggable-tag-cloud/
  def tag_cloud(tags, classes)
      max, min = 0, 0
      tags.each { |t|
        max = t.count.to_i if t.count.to_i > max
        min = t.count.to_i if min == 0 || t.count.to_i < min
      }
      divisor = ((max - min) / classes.size) + 1    
      tags.each { |t|
        yield t.name, classes[(t.count.to_i - min) / divisor]
      }
  end
end
