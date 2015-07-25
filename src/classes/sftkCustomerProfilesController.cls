public class sftkCustomerProfilesController{
	List<Account> accounts;

    public sftkCustomerProfilesController() {
        
    }
	public List<Account> getAccounts() {
       accounts = [SELECT Id, Name, Site FROM Account];
        return accounts;
    }
}