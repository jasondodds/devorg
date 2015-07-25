@isTest
private class GroupCalendarController_Test {
	
	@isTest static void test_controller_constructor() {
		//GroupCalendarController controller = new GroupCalendarController();
		System.assertEquals(GroupCalendarController.DEFAULT_DATE, Date.newInstance(2014, 1, 1));
		//System.assertEquals(controller.selectedGroup.Name,'Demo Users');
	}
	
	@isTest static void test_create_test_data() {
		TestData data = new TestData();
		Integer userCount = data.users.size();
		System.assert(userCount == 2, 'There should be 2 users created.  Actual: '+userCount);
		Integer groupCount = data.groups.size();
		System.assert(groupCount == 2, 'There should be 2 groups created.  Actual: '+groupCount);
	}

	@isTest static void test_create_calendar_data(){
        User currentUser = createUser();
        System.runAs(currentUser){
            TestData testData = new TestData();
            CalendarData data = new CalendarData(testData);
            Integer calendarConfigCount = data.groupCalendarConfigs.size();
            System.assert(calendarConfigCount == 1, 'There should be 1 groupCalendarConfig1 created.  Actual: '+calendarConfigCount);
            Integer eventsCount = data.events.size();
            System.assert(eventsCount == 2, 'There should be 2 events created.  Actual: '+eventsCount);
        }
        
	}

	@isTest static void test_get_matching_calendar_windows(){
		User currentUser = createUser();
		System.runAs(currentUser){
			TestData testData = new TestData();
			CalendarData calendarData = new CalendarData(testData);
			List<GroupCalendarController.CalendarWindow> calendarWindows = new List<GroupCalendarController.CalendarWindow>();
			for(User user : testData.users){
				calendarWindows.add(new GroupCalendarController.CalendarWindow(user));
			}
			Integer matchingCalendarWindowsCount = GroupCalendarController.getMatchingCalendarWindows(calendarData.events[0], calendarData.groupCalendarConfigs[0].Group_Name__c).size();
			System.assert(matchingCalendarWindowsCount == 2, 'There should be 2 calendar windows for Event 1.  Actual: '+matchingCalendarWindowsCount);
		}
	}
    
    @isTest static void test_get_events(){
        User currentUser = createUser();
        System.runAs(currentUser){
            TestData testData = new TestData();
            CalendarData calendarData = new CalendarData(testData);
            Date calendarStartDate = GroupCalendarController.DEFAULT_DATE.addDays(-1);
            Date calendarEndDate = GroupCalendarController.DEFAULT_DATE.addDays(1);
            List<Event> events = GroupCalendarController.getEvents(calendarStartDate, calendarEndDate, calendarData.groupCalendarConfigs[0].Group_Name__c);
            System.assert(events.size() == calendarData.events.size(), 'There should be 2 events returned for this calendar period.  Actual: '+events.size());
        }
    }
    
	@isTest static void test_get_allocated_windows(){
        System.debug('********************************************************************************');
		User currentUser = createUser();
		System.runAs(currentUser){
			TestData testData = new TestData();
			CalendarData calendarData = new CalendarData(testData);

			Date calendarStartDate = GroupCalendarController.DEFAULT_DATE.addDays(-1);
			Date calendarEndDate = GroupCalendarController.DEFAULT_DATE.addDays(1);

			Integer blockedCalendarWindowsCount = GroupCalendarController.getAllocatedWindows(calendarStartDate, calendarEndDate, calendarData.groupCalendarConfigs[0].Group_Name__c).size();
			System.assert(blockedCalendarWindowsCount == 0, 'There should be 0 blocked calendar events for the period '+calendarStartDate+' - '+calendarEndDate+'.  Actual: '+blockedCalendarWindowsCount);
			List<Event> clonedEvents = calendarData.events.deepClone(false,false,false);
			insert clonedEvents;
			blockedCalendarWindowsCount = GroupCalendarController.getAllocatedWindows(calendarStartDate, calendarEndDate, calendarData.groupCalendarConfigs[0].Group_Name__c).size();
			System.assert(blockedCalendarWindowsCount == 4, 'There should be 4 blocked calendar events for the period '+calendarStartDate+' - '+calendarEndDate+'.  Actual: '+blockedCalendarWindowsCount);
		}
        System.debug('********************************************************************************');
	}
    
    @isTest static void test_add_an_event(){
        User currentUser = createUser();
        System.runAs(currentUser){
            TestData testData = new TestData();
            CalendarData calendarData = new CalendarData(testData);
            GroupCalendarController.RemotingResponse remotingResponse;
            Datetime tempDateTime = Datetime.newInstance(GroupCalendarController.DEFAULT_DATE, Time.newInstance(11, 0, 0, 0));
            Event newEvent = new Event(StartDateTime=tempDateTime.addHours(2), EndDateTime=tempDateTime.addHours(3), OwnerId=testData.users[0].Id);
            remotingResponse = GroupCalendarController.addEvent(newEvent, calendarData.groupCalendarConfigs[0].Group_Name__c);
            System.assert(remotingResponse.success, 'An activation should be created');
            System.assert(remotingResponse.message == 'success', 'The response message should be "success"');
            Integer eventCount = GroupCalendarController.getEvents(GroupCalendarController.DEFAULT_DATE.addDays(-1), GroupCalendarController.DEFAULT_DATE.addDays(1), calendarData.groupCalendarConfigs[0].Group_Name__c).size();
            System.assert(eventCount == 3, 'There should be 3 events on the test calendar. Actual: '+eventCount);
        }
    }
    
    @isTest static void test_update_an_event(){
        User currentUser = createUser();
        GroupCalendarController.RemotingResponse remotingResponse;
        Event responseEvent;
        System.runAs(currentUser){
            TestData testData = new TestData();
            CalendarData calendarData = new CalendarData(testData);
            Datetime tempDateTime = Datetime.newInstance(GroupCalendarController.DEFAULT_DATE, Time.newInstance(11, 0, 0, 0));
            Event newEvent = new Event(StartDateTime=tempDateTime.addHours(2), EndDateTime=tempDateTime.addHours(3), Subject='pre-update');
            remotingResponse = GroupCalendarController.addEvent(newEvent, calendarData.groupCalendarConfigs[0].Group_Name__c);
            System.assert( remotingResponse.success, 'An activation should be created');
            responseEvent = remotingResponse.calendarEvent;
            responseEvent.Subject = 'post-update';
            remotingResponse = GroupCalendarController.updateEvent(responseEvent, calendarData.groupCalendarConfigs[0].Group_Name__c);
            System.assert(remotingResponse.calendarEvent.Subject == 'post-update', 'The event subject should be "post-update".  Actual: '+remotingResponse.calendarEvent.Subject);
        }
    }
    
    @isTest static void test_cancel_an_event(){
        User currentUser = createUser();
        GroupCalendarController.RemotingResponse remotingResponse;
        Event responseEvent;
        System.runAs(currentUser){
            TestData testData = new TestData();
            CalendarData calendarData = new CalendarData(testData);
            Datetime tempDateTime = Datetime.newInstance(GroupCalendarController.DEFAULT_DATE, Time.newInstance(11, 0, 0, 0));
            Event newEvent = new Event(StartDateTime=tempDateTime.addHours(2), EndDateTime=tempDateTime.addHours(3), OwnerId=testData.users[0].Id);
            remotingResponse = GroupCalendarController.addEvent(newEvent, calendarData.groupCalendarConfigs[0].Group_Name__c);
            System.assert( remotingResponse.success, 'An activation should be created');
            responseEvent = remotingResponse.calendarEvent;
            Integer eventCount = GroupCalendarController.getEvents(GroupCalendarController.DEFAULT_DATE.addDays(-1), GroupCalendarController.DEFAULT_DATE.addDays(1), calendarData.groupCalendarConfigs[0].Group_Name__c).size();
            System.assert(eventCount == 3, 'There should be 3 events on the test calendar. Actual: '+eventCount);
            System.assert(GroupCalendarController.cancelEvent(responseEvent.Id, true), 'The event should be canceled');
            eventCount = GroupCalendarController.getEvents(GroupCalendarController.DEFAULT_DATE.addDays(-1), GroupCalendarController.DEFAULT_DATE.addDays(1), calendarData.groupCalendarConfigs[0].Group_Name__c).size();
            System.assert(eventCount == 2, 'There should be 2 active events on the test calendar. Actual: '+eventCount);
            System.assert(GroupCalendarController.cancelEvent(responseEvent.Id, false), 'The event should be deleted');
            eventCount = GroupCalendarController.getEvents(GroupCalendarController.DEFAULT_DATE.addDays(-1), GroupCalendarController.DEFAULT_DATE.addDays(1), calendarData.groupCalendarConfigs[0].Group_Name__c).size();
            System.assert(eventCount == 2, 'There should be 2 active events on the test calendar. Actual: '+eventCount);
        }
    }

	public class RemotingResponse {
        public Boolean success {get;set;}
        public String message {get;set;}
        public Event event {get;set;}

        public RemotingResponse(Boolean success, String message, Event event){
            this.success = success;
            this.message = message;
            this.event = event;
        }
    }
	
    private class TestData{
    	public List<User> users {get;set;}
    	public List<Group> groups {get;set;}
    	private TestData(){
    		// Users
    		List<User> users = new List<User>();
			users.add(createUser());
			users.add(createUser());
			insert users;
    		this.users = users;

    		// Groups
    		List<Group> groups = new List<Group>();
    		groups.add(new Group(Name='Calendar Parent Group', Type='Regular'));
    		groups.add(new Group(Name='Calendar Test Group', Type='Regular'));
    		insert groups;
    		this.groups = groups;

    		// Group Members
    		List<GroupMember> groupMembers = new List<GroupMember>();
    		// ** Nest Group 2 under Group 1
    		groupMembers.add(new GroupMember(GroupId=groups[0].Id, UserOrGroupId=groups[1].Id));
    		// ** Add User 1 and User 2 under Group 2
    		groupMembers.add(new GroupMember(GroupId=groups[1].Id, UserOrGroupId=users[0].Id));
    		groupMembers.add(new GroupMember(GroupId=groups[1].Id, UserOrGroupId=users[1].Id));
    		insert groupMembers;
    	}
    }

    private class CalendarData{
    	public List<Group_Calendar_Config__c> groupCalendarConfigs {get;set;}
    	public List<Event> events {get;set;}
    	private CalendarData(TestData testData){
    		// Events
            String groupName = 'Calendar Parent Group';
    		List<Event> events = new List<Event>();
    		Datetime tempDateTime = Datetime.newInstance(GroupCalendarController.DEFAULT_DATE, Time.newInstance(11, 0, 0, 0));
            events.add(new Event(StartDateTime=tempDateTime, EndDateTime=tempDateTime.addHours(1), Group_Calendar_Name__c=groupName, Canceled__c=false, OwnerId=testData.users[0].Id, IsPrivate=false));
            events.add(new Event(StartDateTime=tempDateTime.addHours(3), EndDateTime=tempDateTime.addHours(4), Group_Calendar_Name__c=groupName, Canceled__c=false, OwnerId=testData.users[0].Id, IsPrivate=false));
    		insert events;
    		this.events = events;

    		// Calendar Configs
    		List<Group_Calendar_Config__c> groupCalendarConfigs = new List<Group_Calendar_Config__c>();
    		groupCalendarConfigs.add(new Group_Calendar_Config__c(Name='Test Calendar Config', Group_Name__c=groupName));
    		insert groupCalendarConfigs;
    		this.groupCalendarConfigs = groupCalendarConfigs;
    	}
    }

	private static User createUser() {
        Profile p = [select id from profile where name='System Administrator'];
        Integer randomInt = Integer.valueOf(math.rint(math.random()*1000000));
        return new User(
            alias = 'st' + randomInt, 
            email = 'standarduser' + randomInt + '@test.com',
            emailencodingkey = 'UTF-8',
            firstname = 'Im', 
            lastname = 'Testing' + randomInt,
            languagelocalekey = 'en_US',
            localesidkey      = 'en_US', 
            profileid         = p.Id,
            timezonesidkey    = 'America/Los_Angeles', 
            username          ='standarduser' + randomInt + '@testorg.com');
    }

}