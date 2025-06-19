// ------------------ Q1: Prevent insert/update if teacher teaches Hindi ------------------
// Trigger: TeacherTrigger.apex
trigger TeacherTrigger on Teacher__c (before insert, before update) {
    TeacherHandler.validateHindiSubject(Trigger.new);
}

// Class: TeacherHandler.apex
public class TeacherHandler {
    public static void validateHindiSubject(List<Teacher__c> teachers) {
        for (Teacher__c t : teachers) {
            if (t.Subjects__c != null && t.Subjects__c.contains('Hindi')) {
                t.addError('Teachers cannot be assigned to teach Hindi.');
            }
        }
    }
}

// ------------------ Q2: Prevent deleting class with >1 female student ------------------
// Trigger: ClassTrigger.apex
trigger ClassTrigger on Class__c (before delete) {
    ClassHandler.preventDeleteIfMultipleFemales(Trigger.old);
}

// Class: ClassHandler.apex
public class ClassHandler {
    public static void preventDeleteIfMultipleFemales(List<Class__c> classes) {
        Set<Id> classIds = new Set<Id>();
        for (Class__c c : classes) {
            classIds.add(c.Id);
        }
        Map<Id, Integer> femaleCounts = new Map<Id, Integer>();
        for (AggregateResult ar : [SELECT Class__c, COUNT(Id) count FROM Student__c WHERE Gender__c = 'Female' AND Class__c IN :classIds GROUP BY Class__c]) {
            if ((Integer)ar.get('count') > 1) {
                femaleCounts.put((Id)ar.get('Class__c'), (Integer)ar.get('count'));
            }
        }
        for (Class__c c : classes) {
            if (femaleCounts.containsKey(c.Id)) {
                c.addError('Cannot delete class with more than one female student.');
            }
        }
    }
}

// ------------------ Q3: Prevent inserting student if class at max limit ------------------
// Trigger: StudentTrigger.apex
trigger StudentTrigger on Student__c (before insert) {
    StudentHandler.preventOverMaxLimit(Trigger.new);
}

// Class: StudentHandler.apex (Part 1)
public class StudentHandler {
    public static void preventOverMaxLimit(List<Student__c> students) {
        Set<Id> classIds = new Set<Id>();
        for (Student__c s : students) {
            if (s.Class__c != null)
                classIds.add(s.Class__c);
        }
        Map<Id, Class__c> classMap = new Map<Id, Class__c>([SELECT Id, MaxLimit__c FROM Class__c WHERE Id IN :classIds]);
        Map<Id, Integer> currentCounts = new Map<Id, Integer>();
        for (AggregateResult ar : [SELECT Class__c, COUNT(Id) count FROM Student__c WHERE Class__c IN :classIds GROUP BY Class__c]) {
            currentCounts.put((Id)ar.get('Class__c'), (Integer)ar.get('count'));
        }
        for (Student__c s : students) {
            if (s.Class__c != null) {
                Integer count = currentCounts.get(s.Class__c);
                if (count == null) count = 0;
                if (classMap.containsKey(s.Class__c) && count >= classMap.get(s.Class__c).MaxLimit__c) {
                    s.addError('Cannot insert student, class is at max limit.');
                }
            }
        }
    }

// ------------------ Q4: Update MyCount on insert/update ------------------
    public static void updateClassCount(List<Student__c> students) {
        Set<Id> classIds = new Set<Id>();
        for (Student__c s : students) {
            if (s.Class__c != null)
                classIds.add(s.Class__c);
        }
        List<Class__c> updates = new List<Class__c>();
        for (AggregateResult ar : [SELECT Class__c, COUNT(Id) cnt FROM Student__c WHERE Class__c IN :classIds GROUP BY Class__c]) {
            updates.add(new Class__c(Id = (Id)ar.get('Class__c'), MyCount__c = (Integer)ar.get('cnt')));
        }
        update updates;
    }
}

// Trigger: StudentTrigger (cont.)
after insert, after update {
    StudentHandler.updateClassCount(Trigger.new);
}

// ------------------ Q5: Populate CloseDate if stage changes ------------------
// Trigger: OpportunityTrigger.apex
trigger OpportunityTrigger on Opportunity (before update) {
    OpportunityHandler.handleCloseDate(Trigger.new, Trigger.oldMap);
}

// Class: OpportunityHandler.apex (Part 1)
public class OpportunityHandler {
    public static void handleCloseDate(List<Opportunity> newOpps, Map<Id, Opportunity> oldOppMap) {
        for (Opportunity opp : newOpps) {
            Opportunity oldOpp = oldOppMap.get(opp.Id);
            if (oldOpp.StageName != opp.StageName && 
                (opp.StageName == 'CLOSED_WON' || opp.StageName == 'CLOSED_LOST')) {
                opp.CloseDate = Date.today();
            }
        }
    }

// ------------------ Q6: Reset Custom Status deletes students ------------------
    public static void deleteStudentsOnReset(List<Class__c> newClasses, Map<Id, Class__c> oldClasses) {
        Set<Id> toDeleteClassIds = new Set<Id>();
        for (Class__c c : newClasses) {
            Class__c old = oldClasses.get(c.Id);
            if (old != null && old.Custom_Status__c != 'Reset' && c.Custom_Status__c == 'Reset') {
                toDeleteClassIds.add(c.Id);
            }
        }
        List<Student__c> toDelete = [SELECT Id FROM Student__c WHERE Class__c IN :toDeleteClassIds];
        delete toDelete;
    }
}

// Trigger: ClassTrigger (cont.)
after update {
    ClassHandler.deleteStudentsOnReset(Trigger.new, Trigger.oldMap);
}

// ------------------ Q7: Create Opportunity if Account Industry = Agriculture ------------------
// Trigger: AccountTrigger.apex
trigger AccountTrigger on Account (after insert, after update) {
    AccountHandler.createOpportunityIfAgriculture(Trigger.new);
    AccountHandler.updateContactCities(Trigger.new, Trigger.oldMap);
}

// Class: AccountHandler.apex
public class AccountHandler {
    public static void createOpportunityIfAgriculture(List<Account> accounts) {
        List<Opportunity> opps = new List<Opportunity>();
        for (Account acc : accounts) {
            if (acc.Industry == 'Agriculture') {
                opps.add(new Opportunity(Name = acc.Name + ' Deal', AccountId = acc.Id, StageName = 'Prospecting', CloseDate = Date.today()));
            }
        }
        if (!opps.isEmpty()) insert opps;
    }

    public static void updateContactCities(List<Account> newAccs, Map<Id, Account> oldMap) {
        Set<Id> accIds = new Set<Id>();
        for (Account a : newAccs) {
            Account old = oldMap.get(a.Id);
            if (old != null && a.BillingCity != old.BillingCity) {
                accIds.add(a.Id);
            }
        }
        List<Contact> cons = [SELECT Id, AccountId FROM Contact WHERE AccountId IN :accIds];
        List<Contact> updates = new List<Contact>();
        Map<Id, Account> accMap = new Map<Id, Account>(newAccs);
        for (Contact c : cons) {
            updates.add(new Contact(Id = c.Id, MailingCity = accMap.get(c.AccountId).BillingCity));
        }
        if (!updates.isEmpty()) update updates;
    }
}

// ------------------ Q8: Update Manager from BillToContact ------------------
// Trigger: OpportunityTrigger (cont.)
after update {
    OpportunityHandler.populateManagerFromContact(Trigger.new);
}

// Class: OpportunityHandler (Part 2)
public static void populateManagerFromContact(List<Opportunity> opps) {
    Set<Id> contactIds = new Set<Id>();
    for (Opportunity o : opps) {
        if (o.BillToContact__c != null && o.Manager__c == null) {
            contactIds.add(o.BillToContact__c);
        }
    }
    Map<Id, Contact> contacts = new Map<Id, Contact>([SELECT Id, AccountId FROM Contact WHERE Id IN :contactIds]);
    List<Opportunity> toUpdate = new List<Opportunity>();
    for (Opportunity o : opps) {
        if (o.BillToContact__c != null && o.Manager__c == null && contacts.containsKey(o.BillToContact__c)) {
            o.Manager__c = contacts.get(o.BillToContact__c).AccountId;
            toUpdate.add(o);
        }
    }
    if (!toUpdate.isEmpty()) update toUpdate;
}
