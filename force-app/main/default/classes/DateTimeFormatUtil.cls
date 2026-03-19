/*** 
* @author Emmanuel (EMM) 
* @date 09/02/2026 
* @description Utility to format DateTime in the timezone of the user executing the code.
*              Use for any date/time display to the user (Flow, Apex messages, etc.).
***/ 
public with sharing class DateTimeFormatUtil {
    
    /** Default format for display (date + time) */
    private static final String DEFAULT_FORMAT = 'dd/MM/yyyy HH:mm';
    
    /*** 
    * @description Formats a DateTime in the current user's timezone.
    * @param dt DateTime to format (stored in GMT in Salesforce)
    * @return String Formatted string in the executing user's timezone (Flow, page, etc.)
    * @Exception 
    ***/ 
    public static String formatInUserTimezone(Datetime dt) {
        if (dt == null) return '';
        return dt.format(DEFAULT_FORMAT, UserInfo.getTimeZone().getId());
    }
    
    /*** 
    * @description Returns the current DateTime formatted in the user's timezone.
    * @param  
    * @return String Current DateTime formatted in the user's timezone
    * @Exception 
    ***/ 
    public static String formatNowInUserTimezone() {
        return formatInUserTimezone(Datetime.now());
    }
}