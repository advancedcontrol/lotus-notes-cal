require 'rubygems'
require 'log4r'
require 'uri'
require 'date'
require 'dm-core'
require 'fileutils'
require 'ncal2gcal/lotus_notes_calendar'
require 'ncal2gcal/google_calendar'
require 'ncal2gcal/string'
require 'ncal2gcal/counter'
require 'ncal2gcal/sync_entry'


module NCal2GCal
  
  class NotesGoogleSync
    def initialize(params)
      @notes_calendar = NCal2GCal::LotusNotesCalendar.new(params)
      @google_calendar = NCal2GCal::GoogleCalendar.new(params)
      
      @sync_time = nil
      if params[:days]
         @min_sync_time = DateTime.now-params[:days] #*86400
      end
      if params[:days_max]
         @max_sync_time = DateTime.now+params[:days_max] #*86400
      else 
         @max_sync_time = DateTime.now+400 #*86400
      end
      @max_time = DateTime.parse("2038-01-18")
      # do not sync the description unless the users wants to
      @sync_desc = params[:sync_desc] # || true
      @sync_alarm = params[:sync_alarm]
      @sync_names = params[:sync_names]
      
      init_logger
    end
    def init_logger
      FileUtils::mkdir_p('ncal2gcal')
      $logger = Log4r::Logger.new("sync_logger")      
      Log4r::FileOutputter.new('logfile', 
                         :filename=>"#{Dir.pwd}/ncal2gcal/ncal2gcal.log", 
                         :trunc=>false,
                         :level=>Log4r::WARN)
      $logger.add('logfile')
    end
    def sync_events
      @counter = Counter.new
      @sync_time = DateTime.now
      sleep(1)
      
      @notes_calendar.events.each do |notes_event|
        @counter.selects += 1
        if notes_event.repeats?
          notes_event.repeats.each do |r|
            sync_event(notes_event, r.start_time, r.end_time, notes_event.uid+'_'+r.start_time)
          end
        else
          #p notes_event.repeats
          sync_event(notes_event, notes_event.start_time, notes_event.end_time, notes_event.uid)
        end
      end
      del_events()
      @counter.end
      return @counter
    end

    def sync_event(notes_event, start_time, end_time, key)
        sdt = DateTime.parse(start_time)
        return unless sdt < @max_time # workaround 

        if end_time
          edt = DateTime.parse(end_time)
          return unless edt < @max_time # workaround 
        end
        
        #puts DateTime.parse(notes_event.end_time)
        
        if (@min_sync_time and end_time and 
           @min_sync_time > DateTime.parse(end_time)) or
          (@max_sync_time and start_time and
            @max_sync_time < DateTime.parse(start_time))
        then
          @counter.ignored +=1
        else
          #p key
          sync_entry = NCal2GCal::SyncEntry.first(:lotus_notes_uid => key) 
          if sync_entry  
          then
            #puts DateTime.parse(notes_event.end_time)
            #p sync_entry.lotus_notes_last_modified.to_s
            #p notes_event.last_modified
            if sync_entry.lotus_notes_last_modified < notes_event.last_modified
            then
              #!!insert_update(sync_entry,notes_event)
              insert_update(sync_entry,notes_event, start_time, end_time, key)
            else
              print "."
              @counter.ignored +=1
              sync_entry.sync_time = @sync_time
              sync_entry.sync_action = 'N' # none
              sync_entry.save
            end
          else
            add_event(notes_event, start_time, end_time, key)
          end
        end
    end

    def del_events
        NCal2GCal::SyncEntry.all(:sync_time.lt => @sync_time).each do |sync_entry|
          @counter.deletes += 1
          if @google_calendar.del_event(sync_entry.gcal_id)
            print "D"
            sync_entry.destroy
          else 
            sync_entry.sync_time = @sync_time
            sync_entry.sync_action = 'E'
            sync_entry.save
            print "E"
          end
        end
    end
    def init_google_event(notes_event,start_time,end_time)
      event = @google_calendar.new_event
      google_event= set_google_event_attrs(notes_event, event,start_time,end_time )
      google_event.start_time = start_time 
      google_event.end_time = end_time 
      return google_event
    end
    def set_google_event_attrs(notes_event, google_event,start_time=nil,end_time=nil)
      google_event.title = notes_event.subject.asciify if notes_event.subject
      if start_time
        google_event.start_time = start_time     
      else
        google_event.start_time = notes_event.start_time 
      end
      if end_time
        google_event.end_time = end_time 
      else
        google_event.end_time = notes_event.end_time 
      end
      google_event.where = notes_event.where.asciify if notes_event.where
      google_event.all_day = notes_event.all_day?
      
      if (@sync_desc || @sync_names)
        content = ''
        content += notes_event.formatted_names.asciify if (@sync_names and notes_event.all_names.size > 0)
        content += notes_event.content.asciify if @sync_desc      
        google_event.content = content 
        #puts content
      end
      
      if @sync_alarm and notes_event.alarm
        google_event.reminder = {:method =>'alert', :minutes => notes_event.alarm_offset.to_i.to_s }
      end
      
      return google_event
    end
    def get_sync_entry_by_notes_uid(uid)
      e1 = NCal2GCal::SyncEntry.first(:lotus_notes_uid => uid)
      return e1
    end
    def insert_update(sync_entry,notes_event, start_time, end_time, key)
      gcal_event = @google_calendar.find_event(sync_entry.gcal_id)
      if gcal_event == []
        $logger.warn "Event not found for update"
        add_event(notes_event,start_time, end_time,key)
      else 
        update_event(sync_entry, notes_event, gcal_event, start_time, end_time)
      end
    end
   
    def add_event(notes_event, start_time, end_time, key)
      print "I"
      google_event=init_google_event(notes_event, start_time, end_time)
      ret = google_event.save
      $logger.fatal "insert: cannot save gcal event" unless ret
      raise "cannot save gcal event" unless ret
      @counter.inserts +=1
      sync_entry = NCal2GCal::SyncEntry.new
      sync_entry.lotus_notes_uid = key #notes_event.uid
      sync_entry.sync_time = @sync_time
      sync_entry.lotus_notes_last_modified = notes_event.last_modified
      sync_entry.gcal_id = google_event.id
      sync_entry.sync_action = 'I' # insert
      sync_entry.save
    end
    def update_event(sync_entry, notes_event, gcal_event, start_time, end_time)
      print "U"
      @counter.updates +=1
      set_google_event_attrs(notes_event, gcal_event, start_time, end_time)
      ret = gcal_event.save
      $logger.fatal "update: cannot save gcal event" unless ret
      raise "cannot save gcal event" unless ret
      sync_entry.sync_time = @sync_time
      sync_entry.gcal_id = gcal_event.id
      sync_entry.lotus_notes_last_modified = notes_event.last_modified
      sync_entry.sync_action = 'U' # none
      sync_entry.save
    end
  end
  
end