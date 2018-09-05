/*
	Class Name	 : ContactTriggerHandlerTest
	JIRA Ticket	 : UHHMS-99
	Developed By : Ravi On 3rd Sept 2018
	Description	 : Test class for ContactTriggerHandler
*/
@isTest
public class ContactTriggerHandlerTest {
	public static Integer intRecords=200;
	/*
		Method Name : SetUp
		Description : Inserting Users and Custom setting records
	*/
	@TestSetup
	public static void setUp()
	{
		User objHealthPromoterUser = new User(
            ProfileId = [SELECT Id FROM Profile WHERE Name = 'Health Promoters'].Id,
            LastName = 'testHP',
            Email = 'testHP@test.com',
            Username = 'testHP@test.com' + System.currentTimeMillis(),
            CompanyName = 'TEST',
            Title = 'title',
            Alias = 'test',
            TimeZoneSidKey = 'America/Los_Angeles',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ManagerId = UserInfo.getUserId()
        );
        
    	insert objHealthPromoterUser;

		User objSystemAdminsUser = new User(
            ProfileId = [SELECT Id FROM Profile WHERE Name = 'System Administrator'].Id,
            LastName = 'testAdmin',
            Email = 'testAdmin@test.com',
            Username = 'testAdmin@test.com' + System.currentTimeMillis(),
            CompanyName = 'TEST',
            Title = 'title',
            Alias = 'alias',
            TimeZoneSidKey = 'America/Los_Angeles',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ManagerId = UserInfo.getUserId()
        );
        
    	insert objSystemAdminsUser;

    	User objClinicalUser = new User(
            ProfileId = [SELECT Id FROM Profile WHERE Name = 'Clinical Users'].Id,
            LastName = 'testClinicalUser',
            Email = 'testClinicalUser@test.com',
            Username = 'testClinicalUser@test.com' + System.currentTimeMillis(),
            CompanyName = 'TEST',
            Title = 'tmr',
            Alias = 'al',
            TimeZoneSidKey = 'America/Los_Angeles',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ManagerId = UserInfo.getUserId()
        );
        
    	insert objClinicalUser;

    	Owner_to_Plan_IDs__c objCustomSetting = new Owner_to_Plan_IDs__c(SetupOwnerId = objClinicalUser.Id, Plan_IDs__c = '100,101');
		insert objCustomSetting;

		Owner_to_Plan_IDs__c objCustomSettingDefault = new Owner_to_Plan_IDs__c(SetupOwnerId = objHealthPromoterUser.Id, Plan_IDs__c = 'Default');
		insert objCustomSettingDefault;
	}
	/*
		Method Name : testContactInsertOWNER
		Description : Checking for Owner update on inserting Persons
	*/
	@isTest
	public static void testContactInsertOWNER()
	{
		User objClinicalUser = [SELECT Id,Name 
									FROM User 
									WHERE user.profile.Name='Clinical Users' 
										AND isActive=true 
										AND Name='testClinicalUser'
										LIMIT 1];

		User objSystemAdminUser = [SELECT Id,Name 
									FROM User 
									WHERE user.profile.Name='System Administrator' 
										AND isActive=true 
										AND Name='testAdmin'
										LIMIT 1];
        
        System.runAs(objSystemAdminUser)
        {
			List<Contact> lstContacts = new List<Contact>();
			for(Integer i=0;i<intRecords;i++)
			{
				Contact objContact = (Contact)SL_TestDataFactory.createSobject(
																			new Contact(Member_ID__c='200575'+i,
																						Member_Relationship__c='EE',
																						Plan_Id__c='100'),
																			false
																		   );
				Contact objContactNotInPlanIds = (Contact)SL_TestDataFactory.createSobject(
																			new Contact(Member_ID__c='100575'+i,
																						Member_Relationship__c='EE',
																						Plan_Id__c='103'),
																			false
																		   );
				lstContacts.add(objContactNotInPlanIds);
				lstContacts.add(objContact);
			}
			Test.startTest();
	 			 insert lstContacts;
	 		Test.stopTest();
			System.assertEquals(intRecords,[SELECT Id FROM Contact WHERE OwnerId=:objClinicalUser.Id].size());
			System.assertEquals(intRecords,[SELECT Id FROM Contact WHERE OwnerId=:UserInfo.getUserId()].size());
	 	}
	}
	/*
		Method Name : testContactUpdateOWNER
		Description : Checking for Owner update on updating Persons
	*/
	@isTest
	public static void testContactUpdateOWNER()
	{
		User objClinicalUser = [SELECT Id,Name 
									FROM User 
									WHERE user.profile.Name='Clinical Users' 
										AND isActive=true 
										AND Name='testClinicalUser'
										LIMIT 1];
		User objSystemAdminUser = [SELECT Id,Name 
									FROM User 
									WHERE user.profile.Name='System Administrator' 
										AND isActive=true 
										AND Name='testAdmin'
										LIMIT 1];
        
        System.runAs(objSystemAdminUser)
        {
			List<Contact> lstContacts = new List<Contact>();
			for(Integer i=0;i<intRecords;i++)
			{
				Contact objContactEE = (Contact)SL_TestDataFactory.createSobject(
																			new Contact(Member_ID__c='200575'+i,
																						Member_Relationship__c='EE',
																						Plan_Id__c='103'),
																			false
																		   );
				Contact objContactAC = (Contact)SL_TestDataFactory.createSobject(
																			new Contact(Member_ID__c='100575'+i,
																						Member_Relationship__c='AC',
																						Plan_Id__c='103'),
																			false
																		   );
				lstContacts.add(objContactEE);
				lstContacts.add(objContactAC);
			}
			insert lstContacts;
			
			System.assertEquals(0,[SELECT Id FROM Contact WHERE OwnerId=:objClinicalUser.Id].size());
			System.assertEquals(intRecords*2,[SELECT Id FROM Contact WHERE OwnerId=:UserInfo.getUserId()].size());

			List<Contact> lstConsToUpdate = new List<Contact>();
			for(Contact objCon : [SELECT Id 
									FROM Contact 
									WHERE Member_Relationship__c = 'EE'])
			{
				objCon.Member_Relationship__c='C';
				objCon.Plan_Id__c = '100';
				lstConsToUpdate.add(objCon);
			}

			for(Contact objCon : [SELECT Id 
									FROM Contact 
									WHERE Member_Relationship__c = 'AC'])
			{
				objCon.Member_Relationship__c='EE';
				objCon.Plan_Id__c = '104';
				lstConsToUpdate.add(objCon);
			}

			Test.startTest();
	 			 update lstConsToUpdate;
	 		Test.stopTest();

	 		System.assertEquals(intRecords,[SELECT Id FROM Contact WHERE OwnerId=:objClinicalUser.Id].size());
			System.assertEquals(intRecords,[SELECT Id FROM Contact WHERE OwnerId=:UserInfo.getUserId()].size());
	 	}
	}

	/*
		Method Name : testContactInsertRelationRecords
		Description : Checking Relationship records on inserting Person records
	*/
	@isTest
	public static void testContactInsertRelationRecords()
	{
		User objSystemAdminUser = [SELECT Id,Name 
									FROM User 
									WHERE user.profile.Name='System Administrator' 
										AND isActive=true 
										AND Name='testAdmin'
										LIMIT 1];
        
        System.runAs(objSystemAdminUser)
        {
			List<Contact> lstContacts = new List<Contact>();
			for(Integer i=0;i<intRecords;i++)
			{
				//String strId = '200575'+i;
				Contact objContact = (Contact)SL_TestDataFactory.createSobject(
																			new Contact(Member_ID__c='200575'+i,
																						Member_Relationship__c='EE',
																						Plan_Id__c='100'),
																			false
																		   );
				lstContacts.add(objContact);
			}
			Test.startTest();
	 			 insert lstContacts;
	 		Test.stopTest();
	 		List<String> lstUniqueIds = new List<String>();
	 		for(Contact objCon : lstContacts)
	 		{
	 			lstUniqueIds.add(objCon.Member_ID__c);
	 		}
	 		System.assertEquals(intRecords ,[SELECT Id 
	 											FROM Relationship__c
	 											WHERE Relationship_Type__c='Eligible Employee'
	 												AND Primary_Patient__c IN :lstContacts
	 												AND Unique_Id__c IN :lstUniqueIds
	 												AND Related_To__c = null].size());
	 	}
	}

	/*
		Method Name : testContactUpdateRelationRecords
		Description : Checking Relationship records on updating Person records
	*/
	@isTest
	public static void testContactUpdateRelationRecords()
	{
		User objSystemAdminUser = [SELECT Id,Name 
									FROM User 
									WHERE user.profile.Name='System Administrator' 
										AND isActive=true 
										AND Name='testAdmin'
										LIMIT 1];
        
        System.runAs(objSystemAdminUser)
        {
			List<Contact> lstContacts = new List<Contact>();
			for(Integer i=0;i<intRecords;i++)
			{
				//String strId = '200575'+i;
				Contact objContact = (Contact)SL_TestDataFactory.createSobject(
																			new Contact(Member_ID__c='200575'+i,
																						Member_Relationship__c='AC',
																						Plan_Id__c='103'),
																			false
																		   );
				lstContacts.add(objContact);
			}
			insert lstContacts;
			
			List<String> lstMemberIds = new List<String>();
			List<Contact> lstConsToUpdate = new List<Contact>();
			for(Contact objCon : [SELECT Id,Member_ID__c 
									FROM Contact])
			{
				String strMemId = objCon.Member_ID__c+'1';
				lstMemberIds.add(strMemId);
				objCon.Member_Relationship__c = 'EE';
				objCon.Member_ID__c = strMemId;
				lstConsToUpdate.add(objCon);
			}

			Test.startTest();
	 			 update lstConsToUpdate;
	 		Test.stopTest();

	 		System.assertEquals(intRecords ,[SELECT Id 
	 											FROM Relationship__c
	 											WHERE Relationship_Type__c='Eligible Employee'
	 												AND Primary_Patient__c IN :lstContacts
	 												AND Unique_Id__c IN :lstMemberIds
	 												AND Related_To__c = null].size());
	 	}
	}
}