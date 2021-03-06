require 'rubygems'
require 'ncal2gcal/gcal4ruby_gateway'


module NCal2GCal

  class GoogleCalendar
    attr_accessor :user, :password, :calendar
    attr_reader :events
    def initialize(params)
      @user = params[:gmail_user]
      @password = params[:gmail_password]
      @calendar = params[:gmail_calendar] || "LotusNotes"
      
      service = GCal4Ruby::Service.new
      service.authenticate(@user, @password )
      @cal = GCal4Ruby::Calendar.find(service, @calendar, {:scope => :first})
    end
    def find_event(id)
      return GCal4Ruby::Event.find(@cal, id)
    end
    def new_event
      return GCal4Ruby::Event.new(@cal)
    end
    def del_event(id)
      begin
        event = find_event(id) 
        if event 
          return event.delete unless event == []
        end
      rescue  StandardError => e 
         print 'X'
         $logger.error DateTime.now.to_s
         $logger.error id
         $logger.error e 
      end
      return false
    end
  end

end