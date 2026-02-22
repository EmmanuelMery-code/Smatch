/*** 
* @author Emmanuel (EMM) 
* @date 14/02/2026 
* @description Task IAsyncTask qui appelle l'API Newton (newton.vercel.app) pour additionner 2 entiers
*              et inscrit le résultat dans Calculator_Result__c.
*              L'URL de base est configurée via Custom Label Calculator_Endpoint.
*              Par défaut : https://newton.vercel.app
***/
public with sharing class CalculatorCalloutTask implements IAsyncTask {

    public void run(SF_Async__c contextRecord) {
        Id targetId = contextRecord.Target_Record_Id__c;
        if (targetId == null) {
            throw new AsyncException('Target_Record_Id__c est requis pour CalculatorCalloutTask.');
        }

        Calculator_Result__c rec = [
            SELECT Id, Operand_A__c, Operand_B__c
            FROM Calculator_Result__c
            WHERE Id = :targetId
            LIMIT 1
        ];

        Integer a = rec.Operand_A__c != null ? Integer.valueOf(rec.Operand_A__c) : 0;
        Integer b = rec.Operand_B__c != null ? Integer.valueOf(rec.Operand_B__c) : 0;

        String baseUrl = System.Label.Calculator_Endpoint;
        if (String.isBlank(baseUrl)) {
            baseUrl = 'https://newton.vercel.app';
        }
        baseUrl = baseUrl.replaceAll('/+$', '');
        String expression = a + '+' + b;
        String endpoint = baseUrl + '/api/v2/simplify/' + EncodingUtil.urlEncode(expression, 'UTF-8');

        HttpRequest req = new HttpRequest();
        req.setEndpoint(endpoint);
        req.setMethod('GET');
        req.setTimeout(120000);

        Http http = new Http();
        HttpResponse res = http.send(req);

        if (res.getStatusCode() != 200) {
            throw new AsyncException('Calculator API error: ' + res.getStatusCode() + ' ' + res.getStatus() + ' - ' + res.getBody());
        }

        Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
        Object resultObj = parsed.get('result');
        if (resultObj == null || String.isBlank(String.valueOf(resultObj))) {
            throw new AsyncException('Calculator API: pas de résultat (result absent ou vide) - réponse: ' + res.getBody());
        }

        Decimal resultVal = Decimal.valueOf(String.valueOf(resultObj).trim());

        rec.Result__c = resultVal;
        update rec;
    }

    public class AsyncException extends Exception {}
}