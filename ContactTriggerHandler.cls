/****
 * @Name: 			ContactTriggerHandler
 * @Description: 	This is the trigger handler for the Contact trigger it
 * 					1. Sets the Owner of a Contact (Person) based on the Plan Id of the Contact
 * 					2. Builds relationships between Primary Members and Non Primary Members who are under the Primary Member's plans
 * @CreatedDate: 	2018-08-12
 * @CreatedBy:		Silverline
 ****/


public without sharing class ContactTriggerHandler extends SL_Trigger.baseHandler {
	/**
     * @Name:			beforeInsert
     * @Description:	before insert Default Owner of contacts (persons) inserted based on Plan Id
     * @param:			List<SObject> newList = new list of contacts (persons)
    **/
	public override void beforeInsert(List<SObject> newList){
		defaultBeforeSave((List<Contact>)newList, EligibilityService.mapPlanToOwner);
	}

	/**
     * @Name:			afterInsert
     * @Description:	after insert, upsert relationships between primary and non-primary contacts based on family id
     * 					throw error back to Person record if there was a problem upserting the corresponding relationship record
     * @param:			Map<Id, SObject> newMap - map of Id and new contacts
    **/
    public override void afterInsert(Map<Id, SObject> newMap){
		Schema.SObjectField UniqueIdExternalIdToken = Relationship__c.Fields.Unique_Id__c;
		Map<String,Relationship__c> mapMemberToRelationship = setRelationships(newMap.values());
		Database.UpsertResult[] relationshipUpsertLst = Database.upsert( mapMemberToRelationship.values(), UniqueIdExternalIdToken, false);
		goThroughRelationshipResultsAddErrors(relationshipUpsertLst, mapMemberToRelationship);
	}

	/**
     * @Name:			beforeUpdate
     * @Description:	before update Default Owner of contacts (persons) inserted based on Plan Id
     * @param:			List<SObject> newList = new list of contacts (persons)
     * @param:			Map<Id, SObject> oldMap - map of Id and old contacts
    **/
    public override void beforeUpdate(Map<Id, SObject> oldMap, Map<Id, SObject> newMap){
		defaultBeforeSave(Trigger.new, EligibilityService.mapPlanToOwner);
	}

	/**
     * @Name:			afterUpdate
     * @Description:	after update, upsert relationships between primary and non-primary contacts based on family id
     * 					throw error back to Person record if there was a problem upserting the corresponding relationship record
     * @param:			Map<Id, SObject> newMap - map of Id and new contacts
     * @param:			Map<Id, SObject> oldMap - map of Id and old contacts
    **/
   	public override void afterUpdate(Map<Id, SObject> oldMap, Map<Id, SObject> newMap){
		List<Contact> contactsUpdLst = new List<Contact>();
		Map<Id,Contact> oldContactMap = (Map<Id,Contact>)oldMap;

		for (Contact person : (List<Contact>)newMap.values()){
			if ( person.Member_Relationship__c != oldContactMap.get(person.Id).Member_Relationship__c) {
				contactsUpdLst.add(person);
			}
		}
		Schema.SObjectField UniqueIdExternalIdToken = Relationship__c.Fields.Unique_Id__c;
		Map<String,Relationship__c> mapMemberToRelationship = setRelationships(contactsUpdLst);
		Database.UpsertResult[] relationshipUpsertLst = Database.upsert( mapMemberToRelationship.values() , UniqueIdExternalIdToken, false);
		goThroughRelationshipResultsAddErrors(relationshipUpsertLst, mapMemberToRelationship);
	}


    /* *****
     * @Description
     * 		defaultBeforeSave - defaults values on the person (contact) record before insert or update of a person record
     * 		in particular, 1. sets the Owner based on the Plan ID
     * @param newLst - list of new contacts
     * @param mapPLanToOwnerId - map of Plans to the OwnerId
     * *****/
    private void defaultBeforeSave(List<Contact> newLst, Map<String,Id> mapPlanToOwnerId) {
		for (Contact person : newLst) {
			person.OwnerId = mapPlanToOwnerId.containsKey(person.Plan_Id__c) ? mapPlanToOwnerId.get(person.Plan_ID__c) : UserInfo.getUserId();
		}
    }


	/**
     * @Name:			setRelationships
     * @Description:	derives relationships between contact (person) records based on family ids
     * 					checks for existing contacts and new/updated contacts that may or may not have existing relationship
     * 					each contact should have a relationship record
     * @param:			List<Contact> newLst list of new contacts
    **/
	private Map<String, Relationship__c> setRelationships(List<Contact> newLst) {
		//Create family Ids, relationship mapping, existing code map
		Set<String> familyIds = new Set<String>();
		Map<String, String> mapRelationshipCodeToType = new Map<String,String>();
		Map<String, Contact> mapMemberToPerson = new Map<String,Contact>();

		//Family Maps
		Map<String,String> mapFamilyIdToPrimaryMember = new Map<String,String>();

		//Relationships to process
		Map<String, Relationship__c> mapMemberToRelationship = new Map<String,Relationship__c>();

		//get person records processed to build family maps and set of family Ids
		for (Contact person : newLst) {
			familyIds.add(person.Family_ID__c);
			addToPrimaryFamilyMap(person, mapFamilyIdToPrimaryMember);
			mapMemberToPerson.put(person.Member_ID__c, person);
		}

		//get existing person records matching family ids and add to family maps
		for (Contact person : [Select Id, Family_ID__c, Member_ID__c, Member_Relationship__c From Contact Where Family_ID__c In: familyIds]) {
			addToPrimaryFamilyMap(person, mapFamilyIdToPrimaryMember);
			mapMemberToPerson.put(person.Member_ID__c, person);
		}

		//get relationship code to type description translation mapping
		for (Membership_Relationship_Type__mdt mapping : [Select DeveloperName, Description__c From Membership_Relationship_Type__mdt]) {
			mapRelationshipCodeToType.put(mapping.DeveloperName, mapping.Description__c);
		}

		for (String memberId : mapMemberToPerson.keySet()) {
			//only derive a relationship if it is for a Primary Member or for a non-Primary Member that has a corresponding primary member
			if (mapMemberToPerson.get(memberId).Member_Relationship__c == 'EE' || mapFamilyIdToPrimaryMember.containsKey(mapMemberToPerson.get(memberId).Family_ID__c)) {
				mapMemberToRelationship.put(memberId, createRelationship(mapMemberToPerson.get(memberId), mapRelationshipCodeToType, mapFamilyIdToPrimaryMember));
			}
		}

		return mapMemberToRelationship;
	}

	/**
     * @Name:			addToPrimaryFamilyMap
     * @Description:	Adds a person record to mapFamilyIdToPrimaryMember map for a given family id; a family can have only one primary person
     * @param:			Contact person
     * @param:			Map<String,String> mapFamilyIdToPrimaryMember map of family id to primary person
    */
	private void addToPrimaryFamilyMap(Contact person, Map<String,String> mapFamilyIdToPrimaryMember) {
		if (person.Member_Relationship__c == 'EE') {
			mapFamilyIdToPrimaryMember.put(person.Family_ID__c, person.Member_ID__c);
		}
	}

	/**
     * @Name:			createRelationship
     * @Description:	Maps an Eligibility Staging record to a Person (Contact) record
     * @param:		source - Eligibility Staging record
     * @return:		Contact - resulting Person (Contact) record
    */
	private Relationship__c createRelationship(Contact person, Map<String,String> mapRelationshipCodeToType,
			Map<String,String> mapFamilyIdToPrimaryMember) {
		Relationship__c relationship = new Relationship__c();

		relationship.Relationship_Type__c = mapRelationshipCodeToType.get(person.Member_Relationship__c);
		relationship.Unique_Id__c =  person.Member_Id__c; //each person should only have one relationship record specifically for their relationship with the primary plan holder

		//Non-Primary Member
		if (String.isNotBlank(person.Member_Relationship__c) &&  person.Member_Relationship__c != 'EE' && mapFamilyIdToPrimaryMember.containsKey(person.Family_ID__c)) {
			relationship.Primary_Patient__r = new Contact(Member_ID__c = mapFamilyIdToPrimaryMember.get(person.Family_ID__c));
			relationship.Related_To__r = new Contact(Member_ID__c = person.Member_ID__c);
		}
		//Primary Member
		else if (person.Member_Relationship__c == 'EE') {
			relationship.Primary_Patient__c = person.Id;
			relationship.Related_To__c = null;
		}

		return relationship;
	}

	/**
     * @Name:			goThroughRelationshipResultsAddErrors
     * @Description:	Loops through results returned back from upserting relationships; If there is an error for a given member, add the relationship error
     *   				to the person record so the save will fail for that record
     * @param:			Database.UpsertResult[] resultLst - results of upserting relationships
     * @param:			Map<String, Relationship__c> mapMemberToRelationship, map of relationships Members and Relationship records upserted, used to get Member Key related to a result
    */
	private void goThroughRelationshipResultsAddErrors(Database.UpsertResult[] resultLst, Map<String, Relationship__c> mapMemberToRelationship) {
		Map<String, String> mapMemberIdToError = new Map<String, String>();

		//get relationship errors
		Integer inc = 0;
		for (Database.UpsertResult result : resultLst) {
			if (!result.isSuccess()) {
				String error = ''; Integer errorNum = 1;
				for (Database.Error err : result.getErrors()) {
					error += errorNum + ' ' + err.getStatusCode() + ' : ' + err.getMessage() + ' '; errorNum++;
				}
				System.debug('~~~~ EligibilityStagingTriggerHandler::afterInsert person ' + error);
				mapMemberIdToError.put(mapMemberToRelationship.values()[inc].Unique_Id__c, error);
			}
			inc++;
		}

		//add relationship errors to person record, so person record will error out on save
		for (SObject person : Trigger.new) {
			if (mapMemberIdToError.containsKey((String)person.get('Member_Id__c'))) {
				person.addError(mapMemberIdToError.get((String)person.get('Member_Id__c')));
			}
		}
	}
}