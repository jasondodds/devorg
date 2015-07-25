global class GroupCalendarController {
	@TestVisible
	private static final Date DEFAULT_DATE = Date.newInstance(2014, 1, 1);
    public Group_Calendar_Config__c groupCalendarConfig {get;set;}

	public GroupCalendarController(ApexPages.StandardController stdController) {
        this.groupCalendarConfig = (Group_Calendar_Config__c)stdController.getRecord();
	}

    public List<SelectOption> groupOptions {
        get {
            if (groupOptions == null) {
                List<Group> groups = [select Name from Group];
                groups.sort();
                groupOptions = new List<SelectOption>();
                for (Group groupTemp : groups) {
                    if(groupTemp.Name != null){
                        groupOptions.add(new SelectOption(groupTemp.Name, groupTemp.Name));
                    }
                }
            }
            return groupOptions;
        }
        private set;
    }

    public static Group getGroup(String groupName) {
        Group selectedGroup = [SELECT Id, Name FROM Group WHERE Name=:groupName LIMIT 1];
        return selectedGroup;
    }

    public static List<CalendarWindow> getCalendarWindows(List<User> groupUsers){
        List<CalendarWindow> calendarWindows = new List<CalendarWindow>();
        for (User user : groupUsers) {
            calendarWindows.add(new CalendarWindow(user));
        }
        return calendarWindows;
    }

	public static List<User> getGroupUsers(Group selectedGroup){
		Set<id> groupUserIds = GetUserIdsFromGroup(selectedGroup.Id);
		List<User> groupUsers = new List<User>([SELECT Id, Name, Start_Of_Day__c, End_Of_Day__c FROM User WHERE Id IN :groupUserIds]);
		return groupUsers;
	}

	public static Set<id> GetUserIdsFromGroup(Id groupId){
        // store the results in a set so we don't get duplicates
        Set<Id> result=new Set<Id>();
        String userType = Schema.SObjectType.User.getKeyPrefix();
        String groupType = Schema.SObjectType.Group.getKeyPrefix();
        
        // Loop through all group members in a group
        for (GroupMember m : [Select Id, UserOrGroupId From GroupMember Where GroupId = :groupId]){
            // If the user or group id is a user
            if (((String)m.UserOrGroupId).startsWith(userType)){
                result.add(m.UserOrGroupId);
            }
            // If the user or group id is a group (Note: there may be a problem with governor limits if this is called too many times)
            else if (((String)m.UserOrGroupId).startsWith(groupType)){
                // Call this function again but pass in the group found within this group
                result.addAll(GetUserIdsFromGroup(m.UserOrGroupId));
            }
        }
        return result;  
    }

    public static List<CalendarWindow> getMatchingCalendarWindows(Event currentEvent, String groupName){
        List<CalendarWindow> calendarWindows = getCalendarWindows(getGroupUsers(getGroup(groupName)));
        List<CalendarWindow> matchingCalendarWindows = new List<CalendarWindow>();
        for (CalendarWindow calendarWindow : calendarWindows) {
        	Date eventDate = currentEvent.StartDateTime.date();
        	Datetime userDateStart = Datetime.newInstance(currentEvent.StartDateTime.date(), calendarWindow.startTime.time());
        	Datetime userDateEnd = Datetime.newInstance(currentEvent.EndDateTime.date(), calendarWindow.endTime.time());
        	if( (currentEvent.StartDateTime >= userDateStart && currentEvent.StartDateTime < userDateEnd) || (currentEvent.EndDateTime > userDateStart && currentEvent.EndDateTime <= userDateEnd) ){
                matchingCalendarWindows.add(calendarWindow);
            }
        }
        System.debug('Found '+matchingCalendarWindows.size()+' matching calendar windows for this event in the '+groupName+' calendar');
        return matchingCalendarWindows;
    }

    @RemoteAction
    global static List<Event> getAllocatedWindows(Date startDate, Date endDate, String groupName){
        List<Event> closedWindows = new List<Event>();
        System.debug('-------------------------------------------------------------------');
        System.debug('Getting Allocated Windows for '+groupName);
        Set<Id> groupUserIds = GetUserIdsFromGroup(getGroup(groupName).Id);
        System.debug(groupUserIds);
    	Datetime startDateTime = Datetime.newInstance(startDate, Time.newInstance(0, 0, 0, 0));
        Datetime endDateTime = Datetime.newInstance(endDate, Time.newInstance(23, 59, 59, 0));
        List<Event> currentEvents = getEvents(startDate, endDate, groupName);
    	System.debug('Found '+currentEvents.size()+' events for that period');
    	for(Event currentEvent : currentEvents){
    		List<CalendarWindow> calendarWindows = getMatchingCalendarWindows(currentEvent, groupName);
    		System.debug('For the current event '+currentEvent.Id+', found '+calendarWindows.size()+' calendarWindows');
    		List<Event> matchingEvents = new List<Event>();
    		for(Event testEvent : currentEvents){
    			System.debug('***** Testing event against '+testEvent.Id);
    			if( 
                    (testEvent.StartDateTime >= currentEvent.StartDateTime && testEvent.StartDateTime < currentEvent.EndDateTime) || (testEvent.EndDateTime > currentEvent.StartDateTime && testEvent.EndDateTime <= currentEvent.EndDateTime)
                ){
                	System.debug('----- EVENT MATCH -----');
                    matchingEvents.add(testEvent);
                }
    		}
    		System.debug('Conditional: '+matchingEvents.size()+'>='+calendarWindows.size());
    		if (matchingEvents.size() >= calendarWindows.size()) {
    			System.debug('Adding Blocked Event: '+currentEvent.Id);
                closedWindows.add(currentEvent);
            }
    	}
    	return closedWindows;
    }

    @RemoteAction
    global static List<Event> getEvents(Date startDate, Date endDate, String groupName) {
        Set<Id> groupUserIds = GetUserIdsFromGroup(getGroup(groupName).Id);
        System.debug('GETTING EVENTS FOR PERIOD: '+startDate+' - '+endDate);
        List<Event> events = [select Id, Subject, Description, StartDateTime, EndDateTime, Group_Calendar_Name__c FROM Event WHERE StartDateTime >= :startDate AND StartDateTime <= :endDate AND OwnerId IN :groupUserIds AND Canceled__c != true ORDER BY StartDateTime asc];
        System.debug('## '+events.size()+' EVENTS ##');
        return events;
    }

    @RemoteAction
    global static RemotingResponse addEvent(Event jsonEvent, String groupName) {
        String scheduleResult = '';
        try {
            Event newEvent = new Event();
            newEvent.Subject = jsonEvent.Subject;
            newEvent.StartDateTime = jsonEvent.StartDateTime;
            newEvent.EndDateTime = jsonEvent.EndDateTime;
            newEvent.Description = jsonEvent.Description;
            newEvent.Group_Calendar_Name__c = jsonEvent.Group_Calendar_Name__c;
            newEvent.IsPrivate = false;
            if(jsonEvent.WhatId != null){
                newEvent.WhatId = jsonEvent.WhatId;
            }
            if(jsonEvent.OwnerId != null){
                newEvent.OwnerId = jsonEvent.OwnerId;
            }
            scheduleResult = scheduleEvent(newEvent, groupName);
            System.debug('scheduleEvent Result:');
            System.debug(scheduleResult);
            if(scheduleResult == 'Success'){
                System.debug('New Event:');
                System.debug(newEvent);
                return new RemotingResponse(true, 'success', newEvent);
            } else {
                return returnJsonErrorObject(scheduleResult);
            }
        } catch(DmlException e) {
            System.debug('The following exception has occurred when adding Event: ' + e.getMessage());
            return returnJsonErrorObject(e.getMessage());
        }
        return returnJsonErrorObject('There was an error creating this Event');
    }

    public static String scheduleEvent(Event newEvent, String groupName) {    
        List<Event> closedWindows = new List<Event>();
        List<CalendarWindow> calWindows = getMatchingCalendarWindows(newEvent, groupName);
        Set<Id> groupUserIds = GetUserIdsFromGroup(getGroup(groupName).Id);

        List<Event> existingEvents =
            [select Id, StartDateTime, EndDateTime 
             from Event
             where ((StartDateTime >= :newEvent.StartDateTime and StartDateTime < :newEvent.EndDateTime)
             or (EndDateTime > :newEvent.StartDateTime and EndDateTime < :newEvent.EndDateTime)) AND OwnerId IN :groupUserIds AND Canceled__c != true 
             Order By StartDateTime asc];
        Integer existingEventsCount = existingEvents.size();

        //Identify on whether this is an update to an existing 
        Map<Id,Event> existingEventsMap = new Map<Id,Event>();
        Boolean isExistingEvent = false;
        existingEventsMap.putAll(existingEvents);
        isExistingEvent = existingEventsMap.containsKey(newEvent.Id);

        // Loop through all exisiting Events and look for any non-overlapping events which are taking up a count in Existing Events
        for (Event existingEvent : existingEvents) {
            Boolean foundMatch = false;
            // Loop through other existing Event and check dates and ID
            for(Event tempEvent : existingEvents){
                // Am I different and do I start after another found Event ends?
                if(existingEvent.Id != tempEvent.Id && (tempEvent.StartDateTime >= existingEvent.EndDateTime)){
                    // Yes, found a logic match
                    foundMatch = true;
                }
            }
            if(foundMatch){
                // We found an existing Event that did not overlap with this one, so remove it from the count of blocked window slots
                existingEventsCount--;
            }
        }
        // after adjusting the existing event count, is there at least one unallocated window?
        if ((existingEventsCount >= calWindows.size()) && !isExistingEvent)  {
            return 'No slots available for the requested Event time';
        }

        upsert newEvent;

        return 'Success';
    }

    @RemoteAction
    global static RemotingResponse updateEvent(Event updateEvent, String groupName) {
        String scheduleResult = '';
        System.debug('Updating Event');
        System.debug(updateEvent);
        if(updateEvent.Id != null){
            Event persistedEvent = [
                select Id, Subject, Description, StartDateTime, EndDateTime 
                from Event
                where Id = :updateEvent.Id LIMIT 1
            ];
            if(persistedEvent != null) {
                try {
                    persistedEvent.StartDateTime = updateEvent.StartDateTime;
                    persistedEvent.EndDateTime = updateEvent.EndDateTime;
                    persistedEvent.Subject = updateEvent.Subject;
                    persistedEvent.Description = updateEvent.Description;
                    persistedEvent.Group_Calendar_Name__c = updateEvent.Group_Calendar_Name__c;
                    scheduleResult = scheduleEvent(persistedEvent,groupName);
                    if(scheduleResult == 'Success'){
                        return new RemotingResponse(true, 'success', persistedEvent);
                    } else {
                        return returnJsonErrorObject(scheduleResult);
                    }
                } catch(DmlException e) {
                    System.debug('The following exception has occurred when updating Event: ' + e.getMessage());
                    return returnJsonErrorObject(e.getMessage());
                }
            }
        } else {
            return returnJsonErrorObject('This Event does not have a valid Id');
        }
        return returnJsonErrorObject('There was an error updating this Event');
    }
    
    @RemoteAction
    global static Boolean cancelEvent(Id eventId, Boolean saveCanceled) {
        if(eventId != null){
            Event event = [select Id, Canceled__c from Event where Id = :eventId];
            if(event != null) {
                try {
                    if(saveCanceled) {
                        event.Canceled__c = true;
                        update event;
                    } else {
                        delete event;
                    }
                    return true;
                } catch(DmlException e) {
                    System.debug('The following exception has occurred when cancelling event: ' + e.getMessage());
                }
            }
        }
        return false;
    }

    private static RemotingResponse returnJsonErrorObject(String errorMessage) {
        System.debug('jsonErrorObject Error:');
        System.debug(errorMessage);
        return new RemotingResponse(false, errorMessage, null);
    }

    global class RemotingResponse {
        public Boolean success {get;set;}
        public String message {get;set;}
        public Event calendarEvent {get;set;}

        public RemotingResponse(Boolean success, String message, Event calendarEvent){
            this.success = success;
            this.message = message;
            this.calendarEvent = calendarEvent;
        }
    }

    public class CalendarWindow {
    	public User user {get;set;}
    	public Datetime startTime {get;set;}
    	public Datetime endTime {get;set;}

    	public CalendarWindow(User user){
    		this.user = user;
    		String startOfDay = (user.Start_Of_Day__c != null) ? user.Start_Of_Day__c : '8';
    		String endOfDay = (user.End_Of_Day__c != null) ? user.End_Of_Day__c : '17';
    		this.startTime = Datetime.newInstance(DEFAULT_DATE, Time.newInstance(Integer.valueOf(startOfDay), 0, 0, 0));
    		this.endTime = Datetime.newInstance(DEFAULT_DATE, Time.newInstance(Integer.valueOf(endOfDay), 0, 0, 0));
    	}
    }
}