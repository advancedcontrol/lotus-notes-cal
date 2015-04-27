require 'rubygems'
require 'gcal4ruby'

##
# This is an extension/modification of the classes 
# in the gcal4ruby-module
#
# at the moment it is only used to allaw the usage 
# of the user-relevant end-date in all-day events
#
module GCal4Ruby
 DAY_SECS = 86400
 class Event
    
   alias :start_time= :start=
   alias :start_time :start  

   def all_day=(is_all_day)
     if self.end and !(is_all_day == @all_day)
       is_all_day ? self.end=(self.end()+DAY_SECS) :  self.end=(self.end-DAY_SECS)
     end
     @all_day = is_all_day
   end
   ##
   # The event end date and time 
   # For all_day-events it is the day, when 
   # the event ends (and not the day after 
   # as in the google api)
   #
   def end_time=(t)
     tc = convert_to_time(t)
     if @all_day
       self.end = tc + DAY_SECS
     else
       self.end = tc
     end
   end
   #
   # see end_time=()
   def end_time
     if @all_day
       return (self.end-DAY_SECS)
     else
       return self.end()
     end
   end

   def convert_to_time(t)
      if t.is_a?String
        return Time.parse(t)      
      elsif t.is_a?Time
        return t
      else
        raise "Time must be either Time or String"
      end
   end
   
 end
end
# ---