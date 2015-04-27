require 'win32ole'

module NCal2GCal
  class EventRepeat
    attr_accessor   :start_time, :end_time
    def initialize
    end
  end
  class LotusNotesCalendar
    attr_accessor :server, :user, :password, :db 
    attr_reader :events
    def initialize(params)
      @server = params[:notes_server] || '' # local
      @user = params[:notes_user] 
      @password = params[:notes_password] 
      @db = params[:notes_db] 
      
      session = WIN32OLE.new 'Lotus.NotesSession'
      session.Initialize(@password)
      db = session.GetDatabase(@server, @db)
      raise "unable to open database: #{db}" unless db.isOpen

      @events = LotusNotesEvents.new(db.GetView("$Calendar"))
      raise "$Calendar View not found" unless @events
    end
  end
  class LotusNotesEvents
    def initialize(view)
      @calendar_view = view
    end
    def each
      max = 2000
      count = 0

      uid_list = {}
      entry = @calendar_view.GetLastDocument 
      while entry #and count < max
       begin
        count +=1 
        if !entry.IsDeleted
          event = LotusNotesEvent.new(entry)
          if !uid_list[event.uid]
            if event.supported? 
              yield(event)
            else 
              $logger.warn "not supported appointmenttype: " + (event.appointmenttype.to_s || "appointmenttype missing")
            end
            uid_list[event.uid]=true
          end
        end 
       rescue  StandardError => e 
         print 'X'
         $logger.error DateTime.now.to_s
         $logger.error e 
         $logger.error entry
       end
       entry = @calendar_view.GetPrevDocument(entry)
      end
    end
  end
  class LotusNotesEvent
    # Note: The value of the minutes can be any arbitrary number of minutes between 5 minutes to 4 weeks. 
    GCAL_MAX_REMINDER = 40320  # 4 Weeks in minutes
    GCAL_MIN_REMINDER = 5
    APPOINTMENTTYPE = {'0' =>:appointment,
                                   '1' => :anniversary, 
                                   '2' => :all_day_event,
                                   '3' => :meeting,
                                   '4' => :reminder}
    attr_accessor :uid, 
                       :subject, 
                       :where, 
                       :start_time, :end_time,
                       :last_modified, #
                       :appointmenttype,
                       :content,
                       :repeats,
                       :alarm, :alarm_offset,
                       :required_names, :optional_names, :chair # todo ???
                       
    def initialize(notes_event)
      fill_alarm(notes_event)
      
      # Notes Id
      @uid = notes_event.UniversalID
      
      # Subject
      if notes_event.GetFirstItem("Subject")
         @subject = notes_event.GetFirstItem("Subject").Values[0] 
      else
         @subject = ''
         $logger.warn 'no subject. uid: '+@uid
      end 
      
      # 
      if notes_event.GetFirstItem("ROOM")
        @where = notes_event.GetFirstItem("ROOM").Values[0]
      elsif notes_event.GetFirstItem("Location")
        @where = notes_event.GetFirstItem("Location").Values[0]
      else 
        @where = ''
      end
      
      # start date + time
      @start_time = notes_event.GetFirstItem("Startdatetime").Values[0] if notes_event.GetFirstItem("Startdatetime")
      
      # end date + time
      @end_time =  notes_event.GetFirstItem("EndDatetime").Values[0] if notes_event.GetFirstItem("EndDatetime")
      
      # event type
      if notes_event.GetFirstItem("APPOINTMENTTYPE")
        @appointmenttype = APPOINTMENTTYPE[notes_event.GetFirstItem("APPOINTMENTTYPE").Values[0]]
      end
      @last_modified = DateTime.parse(notes_event.LastModified)
      @content = ''
      body = notes_event.GetFirstItem("Body")
      if body
        @content = body.Values unless body.Values.is_a? Array
      end

      fill_repeats(notes_event)
      fill_names(notes_event) if meeting?
    end
    def all_day?
      @appointmenttype and (@appointmenttype == :all_day_event or @appointmenttype == :anniversary)
    end
    def meeting?
      @appointmenttype and (@appointmenttype == :meeting)
    end

    def supported?
      # anniversaries are now (v.0.0.7) supported 
      @appointmenttype #and (@appointmenttype != :anniversary)
    end
    def repeats?
      @repeats.size > 1
    end
    def fill_alarm(notes_event)
      # Alarm
      @alarm = false
      @alarm_offset = 0
      if notes_event.GetFirstItem("$Alarm")
      then
        if notes_event.GetFirstItem("$Alarm").Values[0] == 1.0
        then 
          @alarm = true
          ao = notes_event.GetFirstItem("$AlarmOffset")
          if ao
            aov = ao.Values[0].to_i
            if aov > -GCAL_MIN_REMINDER
              aov = GCAL_MIN_REMINDER
            elsif aov < -GCAL_MAX_REMINDER
              aov = GCAL_MAX_REMINDER
            end
            @alarm_offset = aov.abs
          end
        end
      end

    end
    def fill_repeats(notes_event)
      @repeats = []
      sdts = notes_event.GetFirstItem("Startdatetime") 
      edts = notes_event.GetFirstItem("EndDatetime")
      return unless sdts
      sdts.Values.each_with_index do |val, idx |
         r = EventRepeat.new
         r.start_time = val
         if edts
           r.end_time = edts.Values[idx]
         else
           $logger.warn "EndDatetime default" 
           $logger.warn @subject
           $logger.warn r.start_time
           
           r.end_time = r.start_time
         end 
         @repeats << r
      end
    end
    def formatted_names
      names = "Chair: #{names_to_str(@chair)}\nRequired: "
      names += names_to_str_name_email(@required_names)
      names += "\nOptional: "+names_to_str_name_email(@optional_names)
      names += "\n---\n"
      #p names
      names 
    end
    def names_to_str_name_email(names)
      (names.inject([]) do |x,y| 
        email, name = '', ''
        email = "<#{y[:email]}>" if (y[:email] and y[:email] != '')
        name = "\"#{y[:name]}\" " if (y[:name] and y[:name] != '')

        x << name + email
        x 
      end).join(', ')
    end

    def names_to_str(names)
      (names.inject([]) do |x,y| 
        if y[:email] and y[:email] != ''
           x << y[:email] if y[:email]
        elsif y[:name]
           x << y[:name] if y[:name]
        end
        x 
      end).join(', ')
    end
    def all_names
      names = []
      names += @chair || [] 
      names += @required_names || []
      names += @optional_names || []
      
      names.uniq
    end
    def fill_names(notes_event)
      @chair = fill_chair(notes_event)
      @required_names = fill_notes_names(notes_event, 'AltRequiredNames', 'INetRequiredNames')
      @optional_names = fill_notes_names(notes_event, 'AltOptionalNames', 'INetOptionalNames')
    end  
    def fill_chair(notes_event)
      chair = []
      notes_chair = notes_event.GetFirstItem("CHAIR")
      notes_chair = notes_event.GetFirstItem('AltChair') unless notes_chair
      if notes_chair 
      then 
        notes_chair.Values.each do |name|
          name =~ /^CN=(.*)\/O=(.*)\/C=(.*)/
          chair << {:name => ($1 || name)}
        end
      end
      chair
    end
    def find_email(names, idx)
      email = names[idx]     
      if email 
        email = nil if email == '.'
        email = nil if email == ''
        # email =~ /^CN=(.*)\/O=(.*)\/C=(.*)/
        # email = $1 if $1
      end
      return email
    end
    
    def fill_notes_names(notes_event, notes_attr_name, notes_attr_email = nil)
      names = []
      notes_names = []
      notes_names1 = notes_event.GetFirstItem(notes_attr_name)
      if notes_attr_email 
        notes_names2 = notes_event.GetFirstItem(notes_attr_email) 
        notes_names2 = nil unless (notes_names2 and notes_names2.Values.size == notes_names1.Values.size)
      end
      if notes_names1
        notes_names1.Values.each_with_index do |name, idx|
            email = find_email(notes_names2.Values, idx) if notes_names2
            #name =~ /^CN=(.*)\/O=(.*)\/C=(.*)/
            #email ? short_name = name.split('/')[0] : short_name  # use name+domain if email missing
            short_name = name.split('/')[0]
            # check if name is an email adress
            if !email and short_name =~ /\A([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})\Z/i
               email = short_name
               short_name = ''
            end
            names << {:name => (short_name || ''), :email => (email || '')}
        end
      end
      names
    end
    
  end
end